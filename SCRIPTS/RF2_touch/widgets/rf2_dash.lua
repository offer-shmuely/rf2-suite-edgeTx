local app_name = "rf2_dash"

local baseDir = "/SCRIPTS/RF2_touch/"
local inSimu = string.sub(select(2,getVersion()), -4) == "simu"

local timerNumber = 1

local err_img = bitmap.open(baseDir.."widgets/img/no_connection_wr.png")
-- err_img = bitmap.resize(err_img, wgt.zone.w, wgt.zone.h)

local craft_image

--------------------------------------------------------------
local function log(fmt, ...)
    print(string.format("[%s] "..fmt, app_name, ...))
    return
end
--------------------------------------------------------------

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}


local function tableToString(tbl)
    if (tbl == nil) then return "---" end
    local result = {}
    for key, value in pairs(tbl) do
        table.insert(result, string.format("%s: %s", tostring(key), tostring(value)))
    end
    return table.concat(result, ", ")
end

local function isFileExist(file_name)
    rf2.log("is_file_exist()")
    local hFile = io.open(file_name, "r")
    if hFile == nil then
        rf2.log("file not exist - %s", file_name)
        return false
    end
    io.close(hFile)
    rf2.log("file exist - %s", file_name)
    return true
end

-----------------------------------------------------------------------------------------------------------------

local function update(wgt, options)
    log("update")
    if (wgt == nil) then return end
    wgt.options = options
    log("update options: %s", tableToString(options))

    wgt.values = {
        craft_name = "-------",
        timer_str = "--:--",
        rpm = -1,
        rpm_str = "-1",
        profile_id = -1,
        profile_id_str = "--",
        rate_id = -1,
        rate_id_str = "--",

        vbat = -1,
        vcel = -1,
        cell_percent = -1,
        volt = -1,
        curr = -1,
        curr_max = -1,
        curr_str = "-1",
        curr_max_str = "-1",
        curr_percent = -1,
        curr_max_percent = -1,
        capaTotal = -1,
        capaUsed = -1,
        capaPercent = -1,

        governor_str = "-------",
        bb_enabled = true,
        bb_percent = 0,
        bb_size = 0,
        bb_txt = "Blackbox: --% 0MB",
        rescue_on = false,
        rescue_txt = "--",
        is_arm = false,
        arm_fail = false,
        arm_disable_flags_list = nil,
        arm_disable_flags_txt = "",

        img_last_name = "---",
        img_craft_name_for_image = "---",
        img_box_1 = nil,
        img_replacment_area1 = nil,
        img_box_2 = nil,
        img_replacment_area2 = nil,

        thr_max = -1,
    }

    return wgt
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
    }
    return update(wgt, options)
end
-----------------------------------------------------------------------------------------------------------------

local function drawBlackboxHorz(wgt, myBatt, percent, getPercentColor)
    -- fill batt
    -- local fill_color = getPercentColor(wgt.vPercent)
    lcd.drawFilledRectangle(myBatt.x ,myBatt.y, myBatt.w, myBatt.h, myBatt.bg_color)

    local fill_color = myBatt.bar_color or GREEN
    local fill_color= (getPercentColor~=nil) and getPercentColor(wgt, percent) or GREEN
    lcd.drawFilledRectangle(
        myBatt.x,-- + math.floor(percent / 100 * myBatt.w),
        myBatt.y,
        math.floor(percent / 100 * myBatt.w),
        myBatt.h,
        fill_color)

    lcd.drawRectangle(wgt.zone.x + myBatt.x,wgt.zone.y + myBatt.y,myBatt.w,myBatt.h, LIGHTGREY, 2)
    -- draw battery segments
    -- for i = 1, myBatt.w + myBatt.segments_w, myBatt.segments_w do
    --     lcd.drawRectangle(myBatt.x + i,myBatt.y,myBatt.segments_w,myBatt.h, WHITE, 1)
    -- end

    -- draw plus terminal
    if myBatt.cath == true then
        local tw = 4
        local th = 4
        lcd.drawFilledRectangle(
            myBatt.x + myBatt.w,
            myBatt.y + myBatt.h / 2 - myBatt.cath_h / 2 + th / 2,
            myBatt.cath_w,
            myBatt.cath_h, WHITE)
        lcd.drawFilledRectangle(
            myBatt.x + myBatt.w + tw,
            myBatt.y + myBatt.h / 2 - myBatt.cath_h / 2 + th,
            myBatt.cath_w,
            myBatt.cath_h - th,
            WHITE)
    end
    -- lcd.drawText(myBatt.x + 20, myBatt.y + 5, "aaa", LEFT + MIDSIZE + wgt.text_color or BLUE)
    -- lcd.drawText(myBatt.x + 20, myBatt.y + 5, "bbb", LEFT + MIDSIZE + wgt.text_color or BLUE)
end

local dbgx, dbgy = 100, 100
local function getDxByStick(stk)
    local v = getValue(stk)
    if math.abs(v) < 15 then return 0 end
    local d = math.ceil(v / 400)
    return d
end
local function dbgLayout()
    local dw = getDxByStick("ail")
    dbgx = dbgx + dw
    dbgx = math.max(0, math.min(480, dbgx))

    local dh = getDxByStick("ele")
    dbgy = dbgy - dh
    dbgy = math.max(0, math.min(272, dbgy))
    -- log("%sx%s", dbgx, dbgy)
    -- lcd.drawFilledRectangle(100,100, 70,25, GREY)
    lcd.drawText(400,0, string.format("%sx%s", dbgx, dbgy), FS.FONT_8 + WHITE)
end

local function formatTime(wgt, t1)
    local dd_raw = t1.value
    local isNegative = false
    if dd_raw < 0 then
      isNegative = true
      dd_raw = math.abs(dd_raw)
    end
    -- log("dd_raw: " .. dd_raw)

    local dd = math.floor(dd_raw / 86400)
    dd_raw = dd_raw - dd * 86400
    local hh = math.floor(dd_raw / 3600)
    dd_raw = dd_raw - hh * 3600
    local mm = math.floor(dd_raw / 60)
    dd_raw = dd_raw - mm * 60
    local ss = math.floor(dd_raw)

    local time_str
    if dd == 0 and hh == 0 then
      -- less then 1 hour, 59:59
      time_str = string.format("%02d:%02d", mm, ss)

    elseif dd == 0 then
      -- lass then 24 hours, 23:59:59
      time_str = string.format("%02d:%02d:%02d", hh, mm, ss)
    else
      -- more than 24 hours
      if wgt.options.use_days == 0 then
        -- 25:59:59
        time_str = string.format("%02d:%02d:%02d", dd * 24 + hh, mm, ss)
      else
        -- 5d 23:59:59
        time_str = string.format("%dd %02d:%02d:%02d", dd, hh, mm, ss)
      end
    end
    if isNegative then
      time_str = '-' .. time_str
    end
    return time_str, isNegative
end


local function updateCraftName(wgt)
    wgt.values.craft_name = wgt.mspTool.craftName()
end

local function updateTimeCount(wgt)
    local t1 = model.getTimer(timerNumber - 1)
    local time_str, isNegative = formatTime(wgt, t1)
    wgt.values.timer_str = time_str
end

local function updateRpm(wgt)
    local Hspd = getValue("Hspd")
    if inSimu then Hspd = 1800 end
    wgt.values.rpm = Hspd
    wgt.values.rpm_str = string.format("%d",Hspd)
end

local function updateProfiles(wgt)
    -- Current PID profile
    local profile_id = getValue("PID#")
    if profile_id > 0 then
        wgt.values.profile_id = profile_id
    else
        wgt.values.profile_id = wgt.mspTool and wgt.mspTool.profileId()
    end
    wgt.values.profile_id_str = string.format("%s", wgt.values.profile_id)

    -- Current Rate profile
    local rate_id = getValue("RTE#")
    if rate_id > 0 then
        wgt.values.rate_id = rate_id
    else
        wgt.values.rate_id = wgt.mspTool and wgt.mspTool.rateProfile()
    end
    wgt.values.rate_id_str = string.format("%s", wgt.values.rate_id)
end

local function updateCell(wgt)
    local vbat = getValue("Vbat")
    if vbat == 0 then
        vbat = (rf2fc.msp.cache.mspBatteryState.batteryVoltage or 0) / 100
    end

    local vcel = getValue("Vcel")
    if vcel == 0 then
        vcel = ((rf2fc.msp.cache.mspBatteryState.batteryVoltage or 0) / (rf2fc.msp.cache.mspBatteryConfig.batteryCellCount or 1)) / 100
        -- vcel = rf2fc.msp.cache.mspBatteryConfig.batteryCellCount
    end

    local batPercent = getValue("Bat%")
    if batPercent == 0 then
        batPercent = rf2fc.msp.cache.mspBatteryState.batteryPercentageRemaining or -1
    end
    -- log("vbat: %s, vcel: %s, BatPercent: %s", vbat, vcel, batPercent)

    wgt.values.vbat = vbat
    wgt.values.vcel = vcel
    wgt.values.cell_percent = batPercent
    wgt.values.volt = (wgt.options.showTotalVoltage==1) and vbat or vcel
    wgt.values.cellColor = (vcel < 3.7) and RED or GREEN
end

local function updateCurr(wgt)
    wgt.values.curr = getValue("Curr")
    if wgt.values.curr == 0 then
        wgt.values.curr = math.floor((rf2fc.msp.cache.mspBatteryState.batteryCurrent or 0) / 100)
    end
    wgt.values.curr_str = string.format("%dA", wgt.values.curr)
end

local function updateCapa(wgt)
    -- capacity
    wgt.values.capaTotal = rf2fc.msp.cache.mspBatteryConfig.batteryCapacity or -1
    wgt.values.capaUsed = getValue("Capa")
    -- if wgt.values.capaUsed == 0 and inSimu then
    if wgt.values.capaUsed == 0 then
        -- wgt.values.capaUsed = math.floor(0.75 * wgt.values.capaTotal)
        wgt.values.capaUsed = rf2fc.msp.cache.mspBatteryState and rf2fc.msp.cache.mspBatteryState.batteryCapacityUsed or 0
    end

    if wgt.values.capaTotal == nil or wgt.values.capaTotal == nan or wgt.values.capaTotal ==0 then
        wgt.values.capaTotal = -1
        wgt.values.capaUsed = 0
    end

    if wgt.values.capaTotal == nil or wgt.values.capaTotal == nan or wgt.values.capaTotal ==0 then
        wgt.values.capaTotal = -1
        wgt.values.capaUsed = 0
    end
    wgt.values.capaPercent = math.floor(100 * (wgt.values.capaTotal - wgt.values.capaUsed) / wgt.values.capaTotal)
    local p = wgt.values.capaPercent
    if (p < 10) then
        wgt.values.capaColor = RED
    elseif (p < 30) then
        wgt.values.capaColor = ORANGE
    else
        wgt.values.capaColor = lcd.RGB(0x00963A) --GREEN
    end
end

local function updateGovernor(wgt)
    if wgt.mspTool.governorEnabled() then
        wgt.values.governor_str = string.format("%s", wgt.mspTool.governorMode())
    else
        wgt.values.governor_str = "OFF"
    end
end

local function updateBB(wgt)
    wgt.values.bb_enabled = wgt.mspTool.blackboxEnable()

    if wgt.values.bb_enabled then
        local blackboxInfo = wgt.mspTool.blackboxSize()
        if blackboxInfo.totalSize > 0 then
            wgt.values.bb_percent = math.floor(100*(blackboxInfo.usedSize/blackboxInfo.totalSize))
        end
        wgt.values.bb_size = math.floor(blackboxInfo.totalSize/ 1000000)
        wgt.values.bb_txt = string.format("Blackbox: %s mb", wgt.values.bb_size)
    end
    wgt.values.bbColor = (wgt.values.bb_percent < 90) and GREEN or RED
end

local function updateRescue(wgt)
    wgt.values.rescue_on = rf2fc.msp.cache.mspRescueProfile.mode == 1

    -- rescue enabled?
    wgt.values.rescue_txt = wgt.values.rescue_on and "ON" or "OFF"
    -- -- local rescueFlip = rf2fc.msp.cache.mspRescueProfile.flip_mode == 1
    -- -- if rescueOn then
    -- --     txt = string.format("%s (%s)", txt, (rescueFlip) and "Flip" or "No Flip")
    -- -- end
end

local  function updateArm(wgt)
    wgt.values.is_arm = wgt.mspTool.isArmed()
    -- log("isArmed %s:", wgt.values.is_arm)
    local flagList = wgt.mspTool.armingDisableFlagsList()
    wgt.values.arm_disable_flags_list = flagList
    wgt.values.arm_disable_flags_txt = ""

    if flagList ~= nil then
        -- log("disableFlags len: %s", #flagList)
        if (#flagList == 0) then
            -- lcd.drawText(x, y,"ARM", FS.FONT_12 + RED)
        else
            -- lcd.drawText(x, y,"Not Arm", FS.FONT_12 + RED)
            for i in pairs(flagList) do
                -- log("disableFlags: %s", i)
                -- log("disableFlags: %s", flagList[i])
                wgt.values.arm_disable_flags_txt = wgt.values.arm_disable_flags_txt .. flagList[i] .. "\n"
            end

        end
    else
        wgt.values.arm_disable_flags_txt = ""
    end

end

local function updateThr(wgt)
    wgt.values.thr = getValue("Thr")
    wgt.values.thr_max = getValue("Thr+")
    -- local id = getSourceIndex("CH3") --????
    -- local val = (getValue(id)+1024)*100//2048
    -- wgt.values.thr_max = math.max(wgt.values.thr_max, val)
end

local function updateTemperature(wgt)
    wgt.values.EscT = getValue("EscT")
    wgt.values.EscT_max = getValue("EscT+")
    if wgt.values.EscT == 0 then
        wgt.values.EscT = math.floor((rf2fc.msp.cache.mspBatteryState.batteryCurrent or 0) / 100)
    end
    wgt.values.EscT_str = string.format("%d°c", wgt.values.EscT)
    wgt.values.EscT_max_str = string.format("%d°c", wgt.values.EscT_max)
end


local function updateImage(wgt)
    local newCraftName = wgt.values.craft_name
    if newCraftName == wgt.values.img_craft_name_for_image then
        return
    end

    local imageName = "/IMAGES/"..newCraftName..".png"

    if isFileExist(imageName) ==false then
        imageName = "/IMAGES/".. model.getInfo().bitmap

        if imageName == "" or isFileExist(imageName) ==false then
            imageName = baseDir.."widgets/img/rf2_logo.png"
        end

    end

    if imageName ~= wgt.values.img_last_name then
        log("updateImage - model changed, %s --> %s", wgt.values.img_last_name, imageName)

        -- image replacment
        craft_image = bitmap.open(imageName)
        craft_image = bitmap.resize(craft_image, 160,100)
        wgt.values.img_last_name = imageName
        wgt.values.img_craft_name_for_image = newCraftName
    end

end

local function background(wgt)
end

local function refresh(wgt, event, touchState)
    if (wgt == nil) then return end

    local x, y
    -- dbgx, dbgy

    -- lcd.clear()
    lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, lcd.RGB(0x11, 0x11, 0x11))

    local is_avail, err = false, "no RF2_Server widget found"
    if rf2fc ~= nil and rf2fc.mspCacheTools ~= nil then
        is_avail, err = rf2fc.mspCacheTools.isCacheAvailable()
    end

    if is_avail == false then
        lcd.drawText(60 ,5, "Rotorflight Dashboard", FS.FONT_12 + WHITE)
        lcd.drawText(140 ,170, err, FS.FONT_8 + WHITE)
        lcd.drawBitmap(err_img, 150, 40)
        return
    end

    wgt.mspTool = rf2fc.mspCacheTools


    updateCraftName(wgt)
    updateTimeCount(wgt)
    updateRpm(wgt)
    updateProfiles(wgt)
    updateCell(wgt)
    updateCurr(wgt)
    updateCapa(wgt)
    updateGovernor(wgt)
    updateBB(wgt)
    updateRescue(wgt)
    updateArm(wgt)
    updateThr(wgt)
    updateTemperature(wgt)
    updateImage(wgt)


    -- profile
    -- image /touch/images/pids.png
    lcd.drawText(0,0, "Bank", FS.FONT_6 + WHITE)
    lcd.drawText(6,10, string.format("%s", wgt.values.profile_id_str), FS.FONT_16 + BLUE)

    -- rate
    -- image /touch/images/rates.png
    lcd.drawText(44,0,"Rate", FS.FONT_6 + WHITE)
    -- lcd.drawText(46,10,string.format("%s", wgt.values.rate_id_str), FS.FONT_16 + ORANGE)
    lcd.drawText(46,10,string.format("%s", wgt.values.rate_id_str), FS.FONT_16 + ORANGE)

    -- time
    local t1 = model.getTimer(timerNumber - 1)
    local time_str, isNegative = formatTime(wgt, t1)
    lcd.drawText(140,50, time_str, FS.FONT_38 + WHITE)

    -- rpm
    lcd.drawText(185+25,120, "RPM", FS.FONT_6 + WHITE)
    lcd.drawText(185, 130, wgt.values.rpm_str, FS.FONT_16 + WHITE)

    -- voltage
    x, y = 5, 55
    -- log("vbat: %s, vcel: %s, BatPercent: %s", vbat, vcel, batPercent)
    lcd.drawText(x, y, "Battery", FS.FONT_6 + WHITE)
    -- lcd.drawText(x, y, string.format("Cell   %d%%", batPercent), FS.FONT_6 + WHITE)
    lcd.drawText(x, y+12, string.format("%.02fv",wgt.values.volt), FS.FONT_16 + WHITE)
    drawBlackboxHorz(wgt, {x=x, y=y+48,w=110,h=10,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=8, segments_h=20, cath=false},
        wgt.values.cell_percent,
        function()
            return wgt.values.cellColor
        end
    )
    lcd.drawText(90,85, string.format("%d%%", wgt.values.cell_percent), FS.FONT_6 + WHITE)

    -- capacity
    x, y = 5, 132
    -- rf2.log("capacity capaPercent: %s, Total: %s", wgt.values.capaPercent, wgt.values.capaTotal)
    lcd.drawText(x, y -12, string.format("Capacity (Total: %s)", wgt.values.capaTotal), FS.FONT_6 + WHITE)
    drawBlackboxHorz(wgt, {x=x, y=y+5,w=140,h=35,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=30, segments_h=20, cath=false},
        wgt.values.capaPercent
    )
    lcd.drawText(x+25, y+4, string.format("%d%%",wgt.values.capaPercent), FS.FONT_16 + WHITE)

    -- current
    x, y = 350, 110
    lcd.drawText(x, y, "Current", FS.FONT_6 + WHITE)
    local color = (wgt.values.curr < 100) and YELLOW or RED
    lcd.drawText(x, y+12, string.format("%d A", wgt.values.curr), FS.FONT_16 + color)

    -- -- rescue enabled?
    -- x, y = 350+20, 145
    -- local rescueOn = rf2fc.msp.cache.mspRescueProfile.mode == 1
    -- -- local rescueFlip = rf2fc.msp.cache.mspRescueProfile.flip_mode == 1
    -- local txt = rescueOn and "ON" or "OFF"
    -- -- if rescueOn then
    -- --     txt = string.format("%s (%s)", txt, (rescueFlip) and "Flip" or "No Flip")
    -- -- end
    --
    -- lcd.drawText(x, y, "Rescue", FS.FONT_6 + WHITE)
    -- lcd.drawText(x, y+12, txt, FS.FONT_8 + WHITE)

    -- -- governor
    -- x, y = 10, 186
    -- if wgt.mspTool.governorEnabled() then
    --     lcd.drawText(x ,y,string.format("Using RF governor\nmode: %s", wgt.mspTool.governorMode()), FS.FONT_6 + WHITE)
    -- else
    --     lcd.drawText(x ,y,"governor  disabled", FS.FONT_6 + WHITE)
    -- end

    -- blackbox
    x, y = 350, 160
    if wgt.values.bb_enabled then
        lcd.drawText(x, y, wgt.values.bb_txt, FS.FONT_6 + WHITE)
        drawBlackboxHorz(wgt,
            {x=x,y=y+20,w=75,h=20,segments_w=10, color=WHITE, bg_color=GREY, cath_w=10, cath_h=80, segments_h=20, cath=false},
            wgt.values.bb_percent,
            function()
                return wgt.values.bbColor
            end
        )
        -- lcd.drawText(x+10, y+20, string.format("%s%% %sMB", wgt.values.bb_percent, wgt.values.bb_size), FS.FONT_8 + WHITE)
        lcd.drawText(x+25, y+20, string.format("%s%%", wgt.values.bb_percent), FS.FONT_8 + WHITE)
    end

    -- craft name
    x,y = 160, 180
    lcd.drawText(x, y,"Heli Name", FS.FONT_6 + WHITE)
    lcd.drawText(x, y+15, wgt.values.craft_name, FS.FONT_12 + ORANGE)
    -- lcd.drawText(dbgx, dbgy,"Heli: " .. wgt.values.craft_name, FS.FONT_12 + ORANGE)

    -- arm
    x, y= 195, 10
    if wgt.values.is_arm then
        lcd.drawText(x, y,"ARM", FS.FONT_12 + RED)
    else
        lcd.drawText(x, y,"Not Arm", FS.FONT_12 + RED)
    end

    local flagList = wgt.values.arm_disable_flags_list
    if flagList ~= nil then
        -- log("disableFlags len: %s", #flagList)
        if (#flagList == 0) then
        else
            y = y + 30
            for i in pairs(flagList) do
                -- log("disableFlags: %s", i)
                -- log("disableFlags: %s", flagList[i])
                lcd.drawFilledRectangle(x,y,130, 20, RED)
                lcd.drawText(x+5, y+1,flagList[i], FS.FONT_8 + WHITE)
                y = y + 25
            end

        end
    else
        log("disableFlags: no info")
    end


    -- image
    -- lcd.drawFilledRectangle(LCD_W-100, 0, 100, 100, GREY)
    if craft_image~=nil then
        lcd.drawBitmap(craft_image, LCD_W-160, 0)
    end


    -- if rf2fc.msp.cache.mspStatus.flightModeFlags then
    --     rf2.log("---flightModeFlags: %x", rf2fc.msp.cache.mspStatus.flightModeFlags)
    -- else
    --     rf2.log("---flightModeFlags: nil")
    -- end

    -- x,y = 440,10
    -- lcd.drawFilledRectangle(x,y, 5,170, GREEN)
    -- lcd.drawFilledRectangle(x+25,y, 6,170, GREEN)
    -- lcd.drawText(x, y+170,"TP", FS.FONT_6 + WHITE)
    -- lcd.drawText(x+25, y+170,"RQ", FS.FONT_6 + WHITE)
    -- -- lcd.drawText(x+5, y+195,"80%", FS.FONT_8 + WHITE + BOLD)

    -- lcd.drawText(x+0, y+180,"TPwr", FS.FONT_6 + GREY)
    -- lcd.drawText(x+0, y+195,"500mw", FS.FONT_6 + WHITE)
    -- -- lcd.drawArc(200, 260, 80, -80, 80, BLUE + DOTTED)

--    dbgLayout()
end

return {name=app_name, create=create, update=update, background=background, refresh=refresh}
