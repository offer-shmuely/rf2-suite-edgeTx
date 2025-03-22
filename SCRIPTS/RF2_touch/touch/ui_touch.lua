local LUA_VERSION = ...
local app_name = "RF2_touch"

local uiStatus = {
    splash   = 0,
    init     = 1,
    mainMenu = 2,
    pages    = 3,
}

local pageStatus = {
    display = 1,
    editing = 2,
    saving  = 3,
}

local uiMsp = {
    reboot = 68,
    eepromWrite = 250,
}

local uiState = uiStatus.splash
local prevUiState
local pageState = pageStatus.display
local requestTimeout = 80
local currentPage = 1
local currentPageName = "---"
local currentField = 1
local saveTS = 0
local saveTimeout = rf2.protocol.saveTimeout
local saveRetries = 0
local maxRetries = rf2.protocol.maxRetries
local killEnterBreak = 0
local pageScrollY = 0
local mainMenuScrollY = 0
local PageFiles, Page, init
local img_title_menu = bitmap.open("touch/images/title_menu.png")

local backgroundFill = TEXT_BGCOLOR or ERASE
local foregroundColor = LINE_COLOR or SOLID

local globalTextOptions = TEXT_COLOR or 0
local template = assert(rf2.loadScript(rf2.radio.template))()

-- ---------------------------------------------------------------------
local function log(fmt, ...)
    -- print(string.format("ui_touch| " .. fmt, ...))
    rf2.print(fmt, ...)
end

local libgui_dir = "/SCRIPTS/" .. app_name .. "/touch/libgui3"
local libGUI = assert(rf2.loadScript("touch/libgui3/libgui3.lua"))(libgui_dir)
libGUI.load_script_flags = "c"
local ctl_fieldsInfo = assert(rf2.loadScript("touch/fields_info.lua"))()
local img_bg1 = nil
local splash_start_time = 0
local btnReload
local btnSave
local isFiledsNeedToSave = false

-- Instantiate main menu GUI panel
local panelTopBar = libGUI.newPanel("panelTopBar")
local panelMainMenu = libGUI.newPanel("mainMenu", {enable_page_scroll=true})
local panelFieldsPage = nil
local modalWatingPanel = nil
local modalWatingCtl = nil

local _tilteCtl
local _title_prefix = "RF2-Touch"
local mspStatusApi = assert(rf2.loadScript("MSP/mspStatus.lua"))()
local _statusTimer_LastTimeFired = nil
local _fcInfo = {
    rateProfile="",
    bank="",
    craftName = "",
}

-- -------------------------------------------------------------------
local modalWatingParams = nil

local function modalWatingStart(text, timeout, retryCount, callbackRetry, callbackGaveup)
    log("modalWating: modalWatingStart(%s)", text)

    local panel = libGUI.newPanel("modalWating")
    modalWatingCtl = panel.newControl.ctl_waiting_dialog(panel, nil, {
        text = text,
        textOrg = text,
        timeout = timeout,
        retryCount = retryCount,
        retries = 0,
        callbackRetry = callbackRetry,
        callbackGaveup = callbackGaveup,
        panel = nil,
    })

    modalWatingPanel = panel
    panel.showPrompt(modalWatingPanel)

end

local function saveSettings()
    if Page.values then
        local payload = Page.values
        if Page.preSave then
            payload = Page.preSave(Page)
        end
        rf2.protocol.mspWrite(Page.write, payload)
        saveTS = getTime()
        if pageState == pageStatus.saving then
            saveRetries = saveRetries + 1
        else
            pageState = pageStatus.saving
            saveRetries = 0
        end
    end
end

local function invalidatePages()
    Page = nil
    panelFieldsPage = nil
    pageState = pageStatus.display
    saveTS = 0
    isFiledsNeedToSave = false
    collectgarbage()
end

local function rebootFc()
    -- rf2.print("Attempting to reboot the FC...")
    -- pageState = pageStatus.rebooting
    rf2.mspQueue:add({
        command = 68, -- MSP_REBOOT
        processReply = function(self, buf)
            invalidatePages()
        end,
        simulatorResponse = {}
    })
end

local mspEepromWrite = {
    command = 250, -- MSP_EEPROM_WRITE, fails when armed
    processReply = function(self, buf)
        if Page.reboot then
            rebootFc()
        else
            invalidatePages()
        end
    end,
    simulatorResponse = {}
}

local function eepromWrite()
    rf2.mspQueue:add(mspEepromWrite)
end

rf2.dataBindFields = function()
    for i = 1, #Page.fields do
        if #Page.values >= Page.minBytes then
            local f = Page.fields[i]
            if f.vals then
                f.value = 0
                for idx = 1, #f.vals do
                    local raw_val = Page.values[f.vals[idx]] or 0
                    raw_val = bit32.lshift(raw_val, (idx - 1) * 8)
                    f.value = bit32.bor(f.value, raw_val)
                end
                local bits = #f.vals * 8
                if f.min and f.min < 0 and bit32.btest(f.value, bit32.lshift(1, bits - 1)) then
                    f.value = f.value - (2 ^ bits)
                end
                f.value = f.value / (f.scale or 1)
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- old msp handling
local mspLoadSettings = {
    processReply = function(self, buf)
        if not Page then return end -- could happen if one returns to the main menu before processReply
        rf2.print("Page is processing reply for cmd "..tostring(self.command).." len buf: "..#buf.." expected: "..Page.minBytes)
        Page.values = buf
        if Page.postRead then
            if Page.postRead(Page) == -1 then
                Page.values = nil
                return
            end
        end
        rf2.dataBindFields()
        if Page.postLoad then
            Page.postLoad(Page)
        end

        Page.isReady = true
    end
}

rf2.readPage = function()
    collectgarbage()

    if type(Page.read) == "function" then
        log("readPage: new way [%s]", Page.title)
        Page.read(Page)
    else
        log("readPage: old way [%s]", Page.title)
        mspLoadSettings.command = Page.read
        mspLoadSettings.simulatorResponse = Page.simulatorResponse
        rf2.mspQueue:add(mspLoadSettings)
    end
end

local function requestPage()
    if not Page.reqTS or Page.reqTS + 2 <= rf2.clock() then
        log("Requesting page... (%s)", Page.title)
        -- Page.reqTS = rf2.clock()
        if Page.read then
            rf2.readPage()
        end
    end
end

local function change_state_to_menu()
    invalidatePages()
    currentField = 1
    uiState = uiStatus.mainMenu
end

local function change_state_to_pages()
    currentField = 1
    invalidatePages()
    uiState = uiStatus.pages
    panelFieldsPage = nil
    Page = nil
end

local function refreshTitle()
    if _tilteCtl then
        local txt
         if uiState == uiStatus.mainMenu then
            txt = string.format("%s [%s] (Bank: %s Rate: %s)", _title_prefix, _fcInfo.craftName, _fcInfo.bank, _fcInfo.rateProfile)
            _tilteCtl.text1 = txt
         elseif uiState == uiStatus.pages then
            txt = string.format("%s (Bank:%s Rate:%s)", _title_prefix, _fcInfo.bank, _fcInfo.rateProfile)
            _tilteCtl.text1 = txt
         end
    end
end

-- draw menu (pages)
local function buildMainMenu()

    local h = 120
    -- local w = 147
    local w = 80
    local lineSpacing_w = 15
    local lineSpacing_h = 10
    local maxLines = 4
    local maxCol = 5
    local col = 0

    _tilteCtl = libGUI.newControl.ctl_title(panelMainMenu, nil, {
        x = 0, y = 0, w = LCD_W, h = 30,
        text1 = _title_prefix,
        text1_x = 10,
        bg_color = panelMainMenu.colors.topbar.bg
    })
    _title_prefix = "RF2-Touch"
    refreshTitle()

    libGUI.newControl.ctl_label(panelMainMenu, nil, {
        x = 435, y = 16,
        text = string.format("v%s",LUA_VERSION),
        text_color = WHITE,
        text_size = panelMainMenu.FONT_SIZES.FONT_6,
    })

    for i = 1, #PageFiles do
        local line = math.floor((i - 1) / maxCol)
        local y = 40 + line * (h + lineSpacing_h)
        local x = 10 + (i - (line * maxCol) - 1) * (w + lineSpacing_w)

        -- local bg = nil -- i.e. default
        local bg = lcd.RGB(0x22, 0x22, 0x22)
        if false then
            bg = panelMainMenu.colors.active
        end

        local txt_title = nil
        if PageFiles[i].type=="per_profile" then
            txt_title = string.format("    Bank - %s", _fcInfo.bank)
        elseif PageFiles[i].type=="per_rate" then
            txt_title = string.format("    Rate - %s", _fcInfo.rateProfile)
        elseif PageFiles[i].type=="esc" then
            txt_title = string.format("    ESC")
        end

        libGUI.newControl.ctl_rf2_button_menu(panelMainMenu, PageFiles[i].t2, {
            x = x,
            y = y,
            w = w,
            h = h,
            text = PageFiles[i].t2,
            bgColor = bg,
            img = PageFiles[i].img,
            title_txt = txt_title,
            onPress = function()
                currentPage = i
                currentPageName = PageFiles[i].title
                change_state_to_pages()
            end
        })
        log("mainMenuBuild: i=%s, col=%s, x=%s, y=%s, w=%s, h=%s (%s)", i, col, x, y, w, h, PageFiles[i].t2)
    end

end

local function getLableIfNeed(lastFieldY, field)
    log("getLableIfNeed: lastFieldY=%s, y=%s   (%s)", lastFieldY, field.y, field.t)

    for i = 1, #Page.labels do
        local lbl = Page.labels[i]

        local exclude_lable = false
        if lbl.t == "RC"
            or lbl.t == "Rate"
            or lbl.t == "ROLL"
            or lbl.t == "PITCH"
            or lbl.t == "YAW"
            or lbl.t == "COL"
            then
            -- log("getLableIfNeed: found label: y=%s (%s)", lbl.y, lbl.t)
            exclude_lable = true
        end
        -- log("getLableIfNeed: found label: y=%s (%s)", y, lbl.t)

        local y = lbl.y
        if y >= lastFieldY and y <= field.y and exclude_lable == false then
            log("getLableIfNeed: found label: y=%s (%s)", y, lbl.t)
            return lbl
        end
    end
    return nil
end

local function clipValue(val, min, max)
    if val < min then
        val = min
    elseif val > max then
        val = max
    end
    return val
end

local function updateValueChange(fieldId, newVal)
    log("number_as_button: updateValueChange(i=%s, newVal=%s)", fieldId, newVal)
    local f = Page.fields[fieldId]
    local scale = f.scale or 1
    local mult = f.mult or 1
    -- f.value = clipValue(newVal/scale, (f.min or 0)/scale, (f.max or 255)/scale)
    f.value = clipValue(newVal, (f.min or 0), (f.max or 255))
    f.value = math.floor(f.value * scale / mult + 0.5) * mult / scale

    if f.vals == nil then
        return
    end
    for idx = 1, #f.vals do
        Page.values[f.vals[idx]] = bit32.rshift(math.floor(f.value * scale + 0.5), (idx - 1) * 8)
    end
    if f.upd and Page.values then
        f.upd(Page)
    end
end

local function buildFieldsPage()
    local yMinLim = rf2.radio.yMinLimit
    local h = 30 -- 24
    local h_btn = 55
    local w = 400
    local lineSpacing = 10
    local lineSpacingLabel = 28
    local maxLines = 6
    local col = 0
    local y = yMinLim + 2
    local last_y = y
    local col_id = 0
    local lastFieldY = 0

    log("buildFieldsPage()")

    panelFieldsPage = libGUI.newPanel("fieldsPage", {enable_page_scroll=true})

    _tilteCtl = libGUI.newControl.ctl_title(panelFieldsPage, nil, {x=0,y=0,w=LCD_W,h=30,text1="RF2",
        text1_x=10, bg_color=panelFieldsPage.colors.topbar.bg
    })
    -- _title_prefix = string.format("RF2 / %s", Page and Page.title or " ---")
    _title_prefix = string.format("/%s", Page and Page.title or " ---")
    refreshTitle()

    btnReload = libGUI.newControl.ctl_button(panelFieldsPage, "btnReload", {x=300,y=2,w=60,h=25,text="Reload",
        onPress=function()
            log("reload-data: %s", Page.title)
            log("reloading data: %s", Page.title)
            modalWatingStart("Reloading data...", 150, 0)
            invalidatePages()
        end
    })
    -- btnReload.disabled = true

    btnSave = libGUI.newControl.ctl_button(panelFieldsPage, "btnSave", {x=400,y=2,w=60,h=25,text="Save", bgColor=RED,
        onPress=function()
            log("saveSettings: %s", Page.title)

            saveSettings()

            modalWatingStart(
                "Saving page fields...",
                rf2.protocol.saveTimeout,
                rf2.protocol.maxRetries+1,
                function()
                    log("modalWating: Retry")
                    saveSettings()
                end,
                function()
                    log("modalWating: gaveup")
                end
            )

        end
    })
    -- btnSave.disabled = true

    -- skip the release & save buttons
    panelFieldsPage.moveFocusAbsolute(#(panelFieldsPage._.elements)) -- (3)

    log("currentPageName: %s", currentPageName)

    -- specific display for some pages
    local firstRegularField = 1

    local pageName = string.gsub(PageFiles[currentPage].script, "%.lua$", "")
    local viewFileName = "touch/page_view/page_view_" .. pageName .. ".lua"
    local vChunk = rf2.loadScript(viewFileName)
    if vChunk then
        log("found: %s", viewFileName)
        local rateTouchView = vChunk(libgui_dir)
        firstRegularField,last_y = rateTouchView.buildSpecialFields(libGUI, panelFieldsPage, Page, y, updateValueChange)
    end

    -- genric display for all pages
    for i = firstRegularField, #Page.fields do
        log("buildFieldsPage: %s. --", i)
        local f = Page.fields[i]
        log("buildFieldsPage: %s. t: [%s]", i, f.t or "NA")

        local txt = f.t2 or f.t or "---"

        local col = 0
        local x = 10
        local units = ""
        if f.id ~= nil then
            if ctl_fieldsInfo[f.id] then
                units = ctl_fieldsInfo[f.id].units
                log("buildFieldsPage: i=%s, units: %s", i, units)
                if not units then
                    units = ""
                end
            end
        end

        local val_x = 250
        local val_w = 150

        -- merging labels into fields, since they are implemented in two different arrays
        local nextLable = getLableIfNeed(lastFieldY, f)
        lastFieldY = f.y
        if nextLable ~= nil then
            col_id = 0
            y = last_y
            libGUI.newControl.ctl_label(panelFieldsPage, nil, {x=x, y=y, w=0, h=h, text=nextLable.t})
            y = y + lineSpacingLabel
            last_y = y
            col_id = 0
        end
        -- end label merging ----------------------------

        local txt2 = string.format("%s \n%s%s", txt, f.value, units)

        if f.label == true then
            col_id = 0
            y = last_y
            libGUI.newControl.ctl_label(panelFieldsPage, txt, {x=x, y=y, w=val_w, h=h, text=txt})
            y = y + lineSpacingLabel
            last_y = y
            col_id = 0
        elseif f.readOnly == true then
                col_id = 0
                y = last_y
                libGUI.newControl.ctl_label(panelFieldsPage, txt, {x=x, y=y, w=val_w, h=h, text=txt})
                y = y + lineSpacingLabel
                last_y = y
                col_id = 0

        elseif f.table ~= nil or (f.data ~= nil and f.data.table ~= nil) then
            col_id = 0
            y = last_y
            local theItems = f.table or f.data.table
            libGUI.newControl.ctl_label(panelFieldsPage, txt, {x=x, y=y, w=0, h=h, text=txt})
            log("buildFieldsPage: i=%s, table0: %s, table1: %s (total: %s)", i, theItems[0], theItems[1], #theItems)
            libGUI.newControl.ctl_dropdown(panelFieldsPage, txt,
                {x=val_x, y=y, w=val_w, h=h, items=theItems, selected=f.value,
                    callback=function(ctl)
                        if f.postEdit then
                            f.postEdit(Page)
                        end
                        local selected1 = ctl.getSelected()
                        local selected0or1based = panelFieldsPage._.tableBasedX_convertSelectedTo0or1Based(selected1, ctl.items0or1)
                        -- log("buildFieldsPage222: i=%s, selected1: %s, selected0or1based: %s", i, selected1, selected0or1based)
                        updateValueChange(i, selected0or1based)
                    end
                } )

            y = y + h + lineSpacing
            last_y = y
            col_id = 0
        else
            local x_Temp = 10 + (col_id * (150 + 6))

            local help = ""
            local units = ""
            local txt_long = ""
            if f.id ~= nil and ctl_fieldsInfo[f.id] then
                txt_long = ctl_fieldsInfo[f.id].t or nil
                help = ctl_fieldsInfo[f.id].help or ""
                units = ctl_fieldsInfo[f.id].units or ""
            end

            local min = f.min or (f.data and f.data.min) or 0
            local max = f.min or (f.data and f.data.max) or 0
            log("number_as_button: i=%s, txt=%s, min:%s,max:%s,scale:%s, mult:%s, steps=%s, raw-val: %s", i, txt, f.min, f.max, f.scale, f.mult, (1/(f.scale or 1))*(f.mult or 1), f.value)
            libGUI.newControl.ctl_rf2_button_number(panelFieldsPage, txt, {
                x=x_Temp, y=y, w=150, h=h_btn,
                min = f.min and f.min / (f.scale or 1),
                max = f.max and f.max / (f.scale or 1),
                steps = (1 / (f.scale or 1)) * (f.mult or 1),
                value = f.value,
                units = units,
                text = txt,
                text_long = txt_long,
                help = help,
                -- callbackOnModalActive=function(ctl)    end,
                -- callbackOnModalInactive=function(ctl)  end
                onValueUpdated = function(ctl, newVal)
                    updateValueChange(i, newVal)
                end
            })

            col_id = col_id + 1
            if col_id > 2 then
                y = y + h_btn + lineSpacing
                col_id = 0
            else
                last_y = y + h_btn + lineSpacing
            end

        end

        log("buildFieldsPage: i=%s, col=%s, y=%s, text: %s", i, col, y, txt2)
    end

    -- -- footer
    -- libGUI.newControl.ctl_title(panelFieldsPage, nil, {x=0,y=LCD_H-15,w=LCD_W,h=15,text1="bank: 1*    cpu=56%",
    -- text1_x=10, bg_color=lcd.RGB(0x2B, 0x79, 0xD7)})

end

local function updateNeedToSaveFlag()
    if panelFieldsPage == nil then
        return false
    end
    -- log("updateNeedToSaveFlag: #panelFieldsPage._.elements=%s", #panelFieldsPage._.elements)

    local tempNeedToSave = false
    for i, ctl in ipairs(panelFieldsPage._.elements) do
        -- log("updateNeedToSaveFlag: %s (%s) %s (%s)", i, ctl, ctl.text, ctl.id)
        if ctl.isDirty then
            -- log("updateNeedToSaveFlag: x=%s,y=%s txt=%s, is_dirty:%s", ctl.x, ctl.y, ctl.text, ctl.isDirty())
            local tempNeedToSave = ctl.isDirty()
            if tempNeedToSave then
                isFiledsNeedToSave = tempNeedToSave
                btnSave.disabled = not isFiledsNeedToSave
                btnReload.disabled = false -- not isFiledsNeedToSave
                return
            end
        end
    end
    isFiledsNeedToSave = false
    btnSave.disabled = true
    btnReload.disabled = false -- not isFiledsNeedToSave

    -- log("updateNeedToSaveFlag: ---isFiledsNeedToSave=%s---", isFiledsNeedToSave)
end

-- ---------------------------------------------------------------------
-- init
-- ---------------------------------------------------------------------

local function run_ui_spalsh(event, touchState)
    if splash_start_time == 0 then
        img_bg1 = bitmap.open("touch/images/splash1.png")
        splash_start_time = getTime()
    end
    lcd.clear()
    lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, GREY)
    lcd.drawBitmap(img_bg1, 0, 0)
    local elapsed = getTime() - splash_start_time;
    local elapsedMili = elapsed * 10;
    -- if (elapsedMili >= 800) then??
    if (elapsedMili >= 10) then
        uiState = uiStatus.init
    end
end

rf2.loadPageFiles = function(setCurrentPageToLastPage)
    PageFiles = assert(rf2.loadScript("pages.lua"))()
    if setCurrentPageToLastPage then
        currentPage = #PageFiles
    end
    collectgarbage()
end

local function run_ui_init(event, touchState)
    img_bg1 = nil
    lcd.clear()
    lcd.drawFilledRectangle(0, 0, LCD_W, 30, COLOR_THEME_SECONDARY1) -- lcd.RGB(0xE0, 0xEC, 0xF0))
    lcd.drawText(10, 5, _title_prefix .. " " .. LUA_VERSION, MENU_TITLE_COLOR)
    lcd.drawText(435, 16, string.format("v%s",LUA_VERSION), MENU_TITLE_COLOR + panelMainMenu.FONT_SIZES.FONT_6 + WHITE)

    init = init or assert(rf2.loadScript("ui_init.lua"))()
    lcd.drawText(10, rf2.radio.yMinLimit, init.t)

    if not init.f() then
        return 0
    end
    init = nil

    -- get craft name
    rf2.useApi("mspName").getModelName(
        function(_, name)
            log("triggering name: %s", name)
            _fcInfo.craftName = name
        end
    )

    rf2.loadPageFiles()
    invalidatePages()
    buildMainMenu()
    uiState = prevUiState or uiStatus.mainMenu
    prevUiState = nil
end

local function run_ui_menu(event, touchState)
    lcd.clear()
    lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, lcd.RGB(0x11, 0x11, 0x11))
    -- lcd.drawBitmap(img_title_menu, 0, 0, 100)

    if libGUI.isNoPrompt() then
        panelMainMenu.draw()
        panelMainMenu.onEvent(event, touchState)
    end

    if event == EVT_VIRTUAL_ENTER_LONG then
        killEnterBreak = 1
    end
end

local function run_ui_pages(event, touchState)
    lcd.clear()
    -- lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, lcd.RGB(0x11, 0x11, 0x11))
    lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, GREY)

    if Page and Page.timer and (not Page.lastTimeTimerFired or Page.lastTimeTimerFired + 0.5 < rf2.clock()) then
        Page.lastTimeTimerFired = rf2.clock()
        log("triggering timer on page: %s", Page.title)
        Page.timer(Page)
    end

    if not Page then
        collectgarbage()
        Page = assert(rf2.loadScript("PAGES/" .. PageFiles[currentPage].script))()
        collectgarbage()
    end

    if not (Page.values or Page.isReady) and pageState == pageStatus.display then
        requestPage()
    end

    if pageState == pageStatus.saving then
        local saveMsg = "Saving..."
        if saveRetries > 0 then
            saveMsg = "Retrying"
        end
        lcd.drawFilledRectangle(rf2.radio.SaveBox.x,rf2.radio.SaveBox.y,rf2.radio.SaveBox.w,rf2.radio.SaveBox.h,backgroundFill)
        lcd.drawRectangle(rf2.radio.SaveBox.x,rf2.radio.SaveBox.y,rf2.radio.SaveBox.w,rf2.radio.SaveBox.h,SOLID)
        lcd.drawText(rf2.radio.SaveBox.x+rf2.radio.SaveBox.x_offset,rf2.radio.SaveBox.y+rf2.radio.SaveBox.h_offset,saveMsg,DBLSIZE + globalTextOptions)
    end

    if panelFieldsPage then
        panelFieldsPage.draw()
        if modalWatingPanel == nil then
            panelFieldsPage.onEvent(event, touchState)
        end
    end

end

local function onProcessedMspStatus(aaa, mspStatusRes)
    -- rf2.log("onProcessedMspStatus")
    _fcInfo.bank = mspStatusRes.profile + 1
    _fcInfo.rateProfile = mspStatusRes.rateProfile + 1

    rf2.log("onProcessedMspStatus()-> B:%s, R:%s", _fcInfo.bank, _fcInfo.rateProfile)
    refreshTitle()
end

local function run_ui(event, touchState)
    -- log("run_ui: [%s] [%s]", event, touchState)

    updateNeedToSaveFlag()

    if libGUI.isNoPrompt() then
        if event == EVT_VIRTUAL_ENTER and killEnterBreak == 1 then
            killEnterBreak = 0
            killEvents(event) -- X10/T16 issue: pageUp is a long press
        end
    end

    local status_interval = 1.5
    if (not _statusTimer_LastTimeFired or _statusTimer_LastTimeFired + status_interval < rf2.clock()) then
        _statusTimer_LastTimeFired = rf2.clock()
        log("triggering _statusTimer_LastTimeFired")

        if rf2.mspQueue:isProcessed() then
            mspStatusApi.getStatus(onProcessedMspStatus, self)
        end
    end

    -- log("run_ui: %s, %s, %s", libGUI.isNoPrompt(), libGUI.showingPrompt, libGUI.prompt)

    if uiState == uiStatus.splash then
        run_ui_spalsh(event, touchState)

    elseif uiState == uiStatus.init then
        run_ui_init(event, touchState)

    elseif uiState == uiStatus.mainMenu then
        run_ui_menu(event, touchState)

    elseif uiState == uiStatus.pages then
        if pageState == pageStatus.display and libGUI.isNoPrompt() then
            if event == EVT_VIRTUAL_EXIT then
                change_state_to_menu()
                return 0
            end
        end

        run_ui_pages(event, touchState)

    end

    if modalWatingPanel then
        local isRetryEnd = modalWatingCtl.calc()
        modalWatingPanel.draw()
        if isRetryEnd then
            -- btnSave.disabled = true
            -- btnReload.disabled = true
            libGUI.dismissPrompt()
            modalWatingPanel = nil
            invalidatePages()
        end
    end

    -- ???
    -- if getRSSI() == 0 then
    --     lcd.drawText(rf2.radio.NoTelem[1],rf2.radio.NoTelem[2],rf2.radio.NoTelem[3],rf2.radio.NoTelem[4])
    -- end

    rf2.mspQueue:processQueue()

    -- log("run_ui: buildFieldsPage(Page: %s,  Page.values: %s, panelFieldsPage: %s, Page.isReady:%s)", Page~=nil, Page and Page.values~=nil or "FALSE", panelFieldsPage~=nil, Page and Page.isReady)
    if panelFieldsPage == nil then
        if (Page and Page.values) or (Page and Page.isReady) then
            buildFieldsPage()
        end
    end

    return 0
end

return run_ui
