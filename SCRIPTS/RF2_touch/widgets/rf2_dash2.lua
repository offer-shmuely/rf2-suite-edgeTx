local app_name = "rf2_dash2"

local baseDir = "/SCRIPTS/RF2_touch/"
local inSimu = string.sub(select(2,getVersion()), -4) == "simu"

local build_ui = nil
local build_ui_modern = nil

local timerNumber = 1

local err_img = bitmap.open(baseDir.."widgets/img/no_connection_wr.png")

local fan = 3
local fanT1 = 0

local wgt = {
    values = {
        craft_name = "-------",
        timer_str = "--:--",
        rpm = -1,
        rpm_str = "---",
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
        capaPercent_txt = "---",

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
    },

    msp = {
        cache = {
            mspPidTuningAll = {
                {
                    roll =  { p = -1, i = -1, d = -1, f = -1},
                    pitch = { p = -1, i = -1, d = -1, f = -1},
                    yaw =   { p = -1, i = -1, d = -1 ,f = -1},
                },
                {
                    roll =  { p = -1, i = -1, d = -1, f = -1},
                    pitch = { p = -1, i = -1, d = -1, f = -1},
                    yaw =   { p = -1, i = -1, d = -1 ,f = -1},
                },
                {
                    roll =  { p = -1, i = -1, d = -1, f = -1},
                    pitch = { p = -1, i = -1, d = -1, f = -1},
                    yaw =   { p = -1, i = -1, d = -1 ,f = -1},
                },
                {
                    roll =  { p = -1, i = -1, d = -1, f = -1},
                    pitch = { p = -1, i = -1, d = -1, f = -1},
                    yaw =   { p = -1, i = -1, d = -1 ,f = -1},
                },
                {
                    roll =  { p = -1, i = -1, d = -1, f = -1},
                    pitch = { p = -1, i = -1, d = -1, f = -1},
                    yaw =   { p = -1, i = -1, d = -1 ,f = -1},
                },
                {
                    roll =  { p = -1, i = -1, d = -1, f = -1},
                    pitch = { p = -1, i = -1, d = -1, f = -1},
                    yaw =   { p = -1, i = -1, d = -1 ,f = -1},
                },
            }
        }
    }
}


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

local function getPidValues(bank, axis, pidType)
    local axisMap = { "roll", "pitch", "yaw" }
    local axisName = axisMap[axis]

    local pidTypeMap = { "p", "i", "d", "f" }
    local pidKey = pidTypeMap[pidType]
    -- log("getPidValues: bank: %d, axis: %s, pidType: %s", bank, axisName, pidKey)
    local value = wgt.msp.cache.mspPidTuningAll[bank][axisName][pidKey]
    return value or "N/A"
    -- return string.format("%d-%d-%d", bank, axis, pidType)
end

local function onReceivedPidTuning(bank, data)
    -- log("onReceivedPidTuning: wgt: %s", wgt)
    -- log("onReceivedPidTuning: wgt: %s, data: %s, roll_p: %s", wgt, data, data.roll_p.value)
    wgt.msp.cache.mspPidTuningAll[bank] = {
        roll =  { p = data.roll_p.value , i = data.roll_i.value , d = data.roll_d.value , f = data.roll_f.value},
        pitch = { p = data.pitch_p.value, i = data.pitch_i.value, d = data.pitch_d.value, f = data.pitch_f.value},
        yaw =   { p = data.yaw_p.value  , i = data.yaw_i.value  , d = data.yaw_d.value  , f = data.yaw_f.value},
    }
end

local function readPids()
    log("readPids: wgt: %s", wgt)

    rf2.useApi("mspSetProfile").setPidProfile(1-1, function() return end, nil)
    rf2.useApi("mspPidTuning").read(onReceivedPidTuning, 1)

    rf2.useApi("mspSetProfile").setPidProfile(2-1, function() return end, nil)
    rf2.useApi("mspPidTuning").read(onReceivedPidTuning, 2)

    rf2.useApi("mspSetProfile").setPidProfile(3-1, function() return end, nil)
    rf2.useApi("mspPidTuning").read(onReceivedPidTuning, 3)

    rf2.useApi("mspSetProfile").setPidProfile(4-1, function() return end, nil)
    rf2.useApi("mspPidTuning").read(onReceivedPidTuning, 4)

    rf2.useApi("mspSetProfile").setPidProfile(5-1, function() return end, nil)
    rf2.useApi("mspPidTuning").read(onReceivedPidTuning, 5)

    rf2.useApi("mspSetProfile").setPidProfile(6-1, function() return end, nil)
    rf2.useApi("mspPidTuning").read(onReceivedPidTuning, 6)

    rf2.useApi("mspSetProfile").setPidProfile(wgt.values.profile_id-1, function() return end, nil)
end

-----------------------------------------------------------------------------------------------------------------

local function buildBlackboxHorz(parentBox, wgt, myBatt, fPercent, getPercentColor)
    local percent = fPercent(wgt)
    local r = 30
    local fill_color = myBatt.bar_color or GREEN
    local fill_color= (getPercentColor~=nil) and getPercentColor(wgt, percent) or GREEN
    local tw = 4
    local th = 4

    -- local box = lvgl.box({x=myBatt.x, y=myBatt.y})
    -- local box = lvgl.box({x=100, y=100})
    -- box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=8, thickness=4})
    -- lvgl.rectangle(box, {w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=8, thickness=4})
    -- box:rectangle({w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=8, thickness=4})

    -- local box2 = lvgl.box({x=200, y=100})
    -- lvgl.rectangle(box2, {x=0, y=0, w=30, h=30, color=BLUE, filled=false, rounded=8, thickness=2})

    local box = parentBox:box({x=myBatt.x, y=myBatt.y})
    box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=myBatt.bg_color, filled=true, rounded=6, thickness=8})
    box:rectangle({x=0, y=0, w=myBatt.w, h=myBatt.h, color=WHITE, filled=false, thickness=myBatt.fence_thickness or 3, rounded=8})
    box:rectangle({x=5, y=5,
        -- w=0, h=myBatt.h,
        filled=true, rounded=4,
        size =function() return math.floor(fPercent(wgt) / 100 * myBatt.w)-10, myBatt.h-10 end,
        color=function() return getPercentColor(wgt, percent) or GREEN end,
    })
    -- draw battery segments
    -- for i=0, myBatt.w, myBatt.segments_w do
    --     box:rectangle({x=i, y=0, w=1, h=myBatt.h, color=LIGHTGREY, filled=true})
    -- end

    -- -- draw plus terminal
    -- if myBatt.cath==true then
    --     box:rectangle({ x=myBatt.w,
    --         y=myBatt.h /2 - myBatt.cath_h /2 + th /2,
    --         w=myBatt.cath_w,
    --         h=myBatt.cath_h,
    --         color=BLUE, filled=true, rounded=1,
    --         -- visible=myBatt.cath -- bug, should support bool
    --     })
    --     box:rectangle({ x=myBatt.w + tw,
    --             y=myBatt.h /2 - myBatt.cath_h /2 + th,
    --             w=myBatt.cath_w,
    --             h=myBatt.cath_h,
    --             color=RED, filled=true, rounded=1,
    --             -- visible=myBatt.cath
    --     })
    -- end

    return box
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
local function dbg_pos()
    log("dbg_pos: %sx%s", dbgx, dbgy)
    return dbgx, dbgy
end
local function dbg_x()
    log("dbg_pos: %sx%s", dbgx, dbgy)
    return dbgx
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

build_ui = function(wgt)
    if (wgt == nil) then log("refresh(nil)") return end
    if (wgt.options == nil) then log("refresh(wgt.options=nil)") return end
    local txtColor = WHITE

    -- local ts_w, ts_h = lcd.sizeText(num_flights, font_size)
    local dx = 20 --(zone_w - ts_w) / 2

    lvgl.clear()

    -- global
    lvgl.rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=lcd.RGB(0x111111), filled=true})
    lvgl.label({text=string.format("%s-LVGL", wgt.options.guiStyle), x=LCD_W-30, y=0, font=FS.FONT_6, color=GREY})
    local pMain = lvgl.box({x=0, y=0, name="panelMain", visible=function() return wgt.is_connected end})

    -- craft name
    local pCraftName = pMain:box({x=160, y=160})
    pCraftName:label({text="Heli Name",  x=0, y=0, font=FS.FONT_6, color=GREY})
    pCraftName:label({text=function() return wgt.values.craft_name end,  x=0, y=15, font=FS.FONT_12 ,color=(wgt.options.guiStyle~=2 and ORANGE or txtColor)})


    -- pid profile (bank)
    pMain:build({{type="box", x=0, y=0,
        children={
            -- {type="rectangle", x=0, y=0, w=40, h=50, color=YELLOW},
            {type="label", text="Bank", x=0, y=0, font=FS.FONT_6, color=GREY},
            {type="label", text=function() return wgt.values.profile_id_str end , x=6, y=10, font=FS.FONT_16 ,color=(wgt.options.guiStyle~=2 and BLUE or txtColor)},
        }
    }})

    -- rate profile
    pMain:build({{type="box", x=44, y=0,
        children={
            -- {type="rectangle", x=0, y=0, w=40, h=50, color=YELLOW},
            {type="label", text="Rate", x=0, y=0, font=FS.FONT_6, color=GREY},
            {type="label", text=function() return wgt.values.rate_id_str end , x=2, y=10, font=FS.FONT_16 ,color=(wgt.options.guiStyle~=2 and ORANGE or txtColor)},
        }
    }})

    -- batt profile
    pMain:build({{type="box", x=86, y=0,
        children={
            {type="label", text="Batt", x=0, y=0, font=FS.FONT_6, color=GREY},
            {type="label", text=function() return "1" end , x=2, y=10, font=FS.FONT_16 ,color=(wgt.options.guiStyle~=2 and YELLOW or txtColor)},
        }
    }})

    -- time
    pMain:build({
        {type="box", x=140, y=50, children={
            {type="label", text=function() return wgt.values.timer_str end, x=0, y=0, font=FS.FONT_38 ,color=WHITE},
        }}
    })

    -- rpm
    pMain:build({{type="box", x=185, y=120,
        children={
            {type="label", text="RPM",  x=25, y=0, font=FS.FONT_6, color=GREY},
            {type="label", text=function() return wgt.values.rpm_str end, x=0, y=10, font=FS.FONT_16 ,color=WHITE},
        }
    }})

    -- voltage
    local bVolt = pMain:box({x=5, y=55})
    bVolt:label({text="Battery", x=0, y=0, font=FS.FONT_6, color=GREY})
    bVolt:label({text=function() return string.format("%.02fv", wgt.values.volt) end , x=0, y=12, font=FS.FONT_16 ,color=WHITE})
    buildBlackboxHorz(bVolt, wgt,
        {x=0, y=48,w=110,h=15,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=8, segments_h=20, cath=true, fence_thickness=1},
        function(wgt) return wgt.values.cell_percent end,
        function(wgt) return wgt.values.cellColor end
    )

    -- capacity
    local bCapa = pMain:box({type="box", x=5, y=120})
    bCapa:label({text=function() return string.format("Capacity (Total: %s)", wgt.values.capaTotal) end,  x=0, y=0, font=FS.FONT_6, color=GREY})
    buildBlackboxHorz(bCapa, wgt,
        {x=0, y=17,w=140,h=35,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=30, segments_h=20, cath=false},
        function(wgt) return wgt.values.capaPercent end,
        function(wgt) return wgt.values.capaColor end
    )
    bCapa:label({text=function() return wgt.values.capaPercent_txt end, x=25, y=16, font=FS.FONT_16 ,color=WHITE})
    -- bCapa:label({text=function() return string.format("%dmah", wgt.values.capaTotal) end, x=5, y=18, font=FS.FONT_8 ,color=WHITE})

    -- current
    local bCurr = pMain:box({x=350, y=110})
    bCurr:label({text="Current",  x=0, y=0, font=FS.FONT_6, color=GREY})
    -- bCurr:label({text=function() return wgt.values.curr_str end, x=0, y=12, font=FS.FONT_16 ,color=function() return (wgt.values.curr < 100) and YELLOW or RED end },
    bCurr:label({text=function() return wgt.values.curr_str end, x=0, y=12, font=FS.FONT_16 ,color=(wgt.options.guiStyle~=2 and YELLOW or txtColor)})

    -- -- governor
    -- pMain:build({{type="box", x=10, y=186,
    --      children={
    --          -- {type="label", text="RPM",  x=25, y=0, font=FS.FONT_6, color=WHITE},
    --          {type="label", text=function() return wgt.values.governor_str end, x=0, y=0, font=FS.FONT_6 ,color=WHITE},
    --      }
    -- }})

    -- blackbox
    local bBB = pMain:box({type="box", x=350, y=160, visible=function() return wgt.values.bb_enabled end})
    bBB:label({text=function() return wgt.values.bb_txt end,  x=0, y=0, font=FS.FONT_6, color=function() return (wgt.values.bb_percent < 90) and GREY or RED end })
    buildBlackboxHorz(bBB, wgt,
        {x=0, y=15,w=110,h=15,segments_w=10, color=WHITE, bg_color=GREY, cath_w=10, cath_h=80, segments_h=20, cath=false, fence_thickness=2},
        function(wgt) return wgt.values.bb_percent end,
        function(wgt) return wgt.values.bbColor end
    )
    -- bBB:label({text=function() return string.format("%s%%", wgt.values.bb_percent) end, x=20, y=20, font=FS.FONT_8 ,color=WHITE})

    -- arm
    local bArm = pMain:box({x=140, y=5})
    -- local dx = 1
    -- for i = 6, 1, -1 do
    --     bArm:rectangle({
    --         x = 10 - (i * dx),
    --         y = 10 - (i * dx),
    --         w = 140 + (2 * i * dx),
    --         h = 30 + (2 * i * dx),
    --         color = (i == 1) and RED or ((i >= 2) and GREY or LIGHTGREY),
    --         filled = true,
    --         rounded = 18,
    --         visible = function() return fan >= i end
    --     })
    -- end

    -- bArm:rectangle({x=10, y=10, w=140, h=30, color=RED, filled=true, rounded=18, visible=function() return fan>=1 end})
    -- bArm:label({text="Arm", x=0, y=0, font=FS.FONT_6, color=WHITE})
    bArm:label({x=22, y=11, text=function() return wgt.values.is_arm and "ARM" or "Not Armed" end, font=FS.FONT_12 ,
        color=function()
            if wgt.options.guiStyle~=2 then
                return wgt.values.is_arm and RED or GREEN
            else
                return WHITE
            end
        end
    })

    -- failed to arm flags
    pMain:build({{type="box", x=150, y=45, visible=function() return wgt.values.arm_fail end,
        children={
            {type="rectangle", x=0, y=0, w=280, h=150, color=RED, filled=true, rounded=8, opacity=245},
            {type="label", text=function() return wgt.values.arm_disable_flags_txt end, x=10, y=0, font=FS.FONT_8, color=WHITE},
        }
    }})

    -- status bar
    local bStatusBar = pMain:box({x=0, y=wgt.zone.h-20})
    local statusBarColor = lcd.RGB(0x0078D4)
    bStatusBar:rectangle({x=0, y=0,w=wgt.zone.w, h=20, color=statusBarColor, filled=true})
    bStatusBar:label({x=3  , y=2, text=function() return string.format("RQLY: %s%% (min: %s)", getValue("RQly"), getValue("RQly-")) end, font=FS.FONT_6, color=WHITE})
    bStatusBar:label({x=140, y=2, text=function() return string.format("TPWR+: %smw", getValue("TPWR+")) end, font=FS.FONT_6, color=WHITE})
    -- bStatusBar:label({x=210, y=2, text=function() return string.format("Gov: %s", wgt.values.governor_str) end, font=FS.FONT_6, color=WHITE})
    bStatusBar:label({x=300, y=2, text=function() return string.format("Thr+: %s%%", wgt.values.thr_max) end, font=FS.FONT_6, color=WHITE})
    bStatusBar:label({x=425, y=2, text="Shmuely", font=FS.FONT_6, color=YELLOW})
    -- bStatusBar:label({x=390, y=2, text=rf2.LUA_VERSION, font=FS.FONT_6, color=WHITE})

    -- image
    local isizew=160
    local isizeh=80
    local bImageArea = pMain:box({x=LCD_W-isizew, y=0, w=isizew, h=isizeh})
    -- local bRect = bImageArea:rectangle({x=0, y=0, w=isizew, h=isizeh, thickness=4, rounded=15, filled=false, color=GREY})
    local bImg = bImageArea:box({})
    wgt.values.img_box_1 = bImg
    wgt.values.img_replacment_area1 = bImageArea

    -- no connection
    local bNoConn = lvgl.box({x=0, y=0, visible=function() return wgt.is_connected==false end})
    bNoConn:label({x=100,  y=5,   text="Rotorflight Dashboard", font=FS.FONT_12, color=WHITE})
    bNoConn:label({x=140, y=170, text=function() return wgt.not_connected_error end , font=FS.FONT_8, color=WHITE})
    bNoConn:image({x=150, y=40, w=128, h=128, file=baseDir.."widgets/img/no_connection_wr.png"})

end

build_ui_modern = function(wgt)
    if (wgt == nil) then log("refresh(nil)") return end
    local txtColor = WHITE

    -- local ts_w, ts_h = lcd.sizeText(num_flights, font_size)
    local dx = 20 --(zone_w - ts_w) / 2

    lvgl.clear()

    -- global
    lvgl.rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=lcd.RGB(0x111111), filled=true})
    lvgl.label({text=string.format("%s-LVGL", wgt.options.guiStyle), x=LCD_W-30, y=0, font=FS.FONT_6, color=GREY})
    local pMain = lvgl.box({x=0, y=0, name="panelMain"
        -- , visible=function() return wgt.is_connected end
    })

    -- pid profile (bank)
    pMain:build({{type="box", x=30, y=150,
        children={
            {type="label", text=function() return wgt.values.profile_id_str end , x=6, y=0, font=FS.FONT_16 ,color=txtColor},
            {type="label", text="Bank", x=0, y=40, font=FS.FONT_6, color=GREY},
        }
    }})

    -- rate profile
    pMain:build({{type="box", x=74, y=150,
        children={
            {type="label", text=function() return wgt.values.rate_id_str end , x=2, y=0, font=FS.FONT_16 ,color=txtColor},
            {type="label", text="Rate", x=0, y=40, font=FS.FONT_6, color=GREY},
        }
    }})

    -- batt profile
    pMain:build({{type="box", x=116, y=150,
        children={
            {type="label", text=function() return "1" end , x=2, y=0, font=FS.FONT_16 ,color=txtColor},
            {type="label", text="Batt", x=0, y=40, font=FS.FONT_6, color=GREY},
        }
    }})

    -- time
    pMain:build({
        {type="box", x=350, y=0, children={
            {type="label", text="Timer", x=0, y=0, font=FS.FONT_6, color=GREY},
            {type="label", text=function() return wgt.values.timer_str end, x=0, y=15, font=FS.FONT_16 ,color=WHITE},
        }}
    })

    -- rpm
    pMain:build({{type="box", x=250, y=0,
        children={
            {type="label", text="Head Speed",  x=0, y=0, font=FS.FONT_6, color=GREY},
            {type="label", text=function() return wgt.values.rpm_str end, x=0, y=15, font=FS.FONT_16 ,color=WHITE},
        }
    }})

    -- capacity
    local bCapa = pMain:box({x=220, y=145})
    bCapa:label({text=function() return string.format("Capacity (Total: %s)", wgt.values.capaTotal) end,  x=0, y=0, font=FS.FONT_6, color=GREY})
    buildBlackboxHorz(bCapa, wgt,
        {x=0, y=17,w=250,h=40,segments_w=20, color=WHITE, bg_color=BLACK, cath_w=10, cath_h=30, segments_h=20, cath=false},
        function(wgt) return wgt.values.capaPercent end,
        function(wgt) return wgt.values.capaColor end
    )
    bCapa:label({text=function() return wgt.values.capaPercent_txt end, x=25, y=16, font=FS.FONT_16 ,color=WHITE})
    -- bCapa:label({text=function() return string.format("%dmah", wgt.values.capaTotal) end, x=5, y=18, font=FS.FONT_8 ,color=WHITE})



    -- current
    local g_rad = 40
    local g_thick = 8--11
    local gm_rad = g_rad-10
    local gm_thick = 8
    local g_y = 55
    local g_angel_min = 140
    local g_angel_max = 400
    local function calEndAngle(percent)
        if percent==nil then return 0 end
        local v = ((percent/100) * (g_angel_max-g_angel_min)) + g_angel_min
        return v
    end

    local bCurr = pMain:box({x=210, y=g_y})
    bCurr:label({text="Current",  x=0, y=0, font=FS.FONT_6, color=GREY})
    bCurr:label({x=30, y=40, text=function() return wgt.values.curr_str end, font=FS.FONT_812, color=WHITE})
    bCurr:label({x=35, y=70, text=function() return wgt.values.curr_max_str end, font=FS.FONT_6, color=lcd.RGB(0x787878)})
    bCurr:arc({x=50, y=50, radius=g_rad, thickness=g_thick, startAngle=g_angel_min, endAngle=g_angel_max, rounded=true, color=lcd.RGB(0x222222)})
    -- bCurr:arc({x=50, y=50, radius=g_rad, thickness=g_thick, startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.curr_max_percent) end, color=lcd.RGB(0xFF623F), opacity=180})
    bCurr:arc({x=50, y=50, radius=gm_rad, thickness=gm_thick, startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.curr_max_percent) end, color=lcd.RGB(0xFF623F), opacity=180})
    bCurr:arc({x=50, y=50, radius=g_rad , thickness=g_thick,  startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.curr_percent)     end, color=lcd.RGB(0xFF623F)})

    -- thr
    local bThr = pMain:box({x=210+2*g_rad+10, y=g_y })
    bThr:label({text="thr",  x=0, y=0, font=FS.FONT_6, color=GREY})
    bThr:label({x=35, y=40, text=function() return string.format("%s%%", wgt.values.thr)      end, font=FS.FONT_8, color=WHITE})
    bThr:label({x=35, y=70, text=function() return string.format("+%s%%", wgt.values.thr_max) end, font=FS.FONT_6, color=GREY})
    bThr:arc({x=50, y=50, radius=g_rad, thickness=g_thick, startAngle=g_angel_min, endAngle=g_angel_max, color=lcd.RGB(0x222222)})
    bThr:arc({x=50, y=50, radius=g_rad, thickness=g_thick, startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.thr_max) end, color=lcd.RGB(0xFFA72C), opacity=80})
    bThr:arc({x=50, y=50, radius=g_rad, thickness=g_thick, startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.thr)     end, color=lcd.RGB(0xFFA72C)})

    -- temp
    local bTemp = pMain:box({x=210+4*g_rad+20, y=g_y})
    bTemp:label({text="temp",  x=0, y=0, font=FS.FONT_6, color=GREY})
    bTemp:label({x=35, y=40, text=function() return (wgt.values.EscT_str or "--°c") end, font=FS.FONT_8, color=WHITE})
    bTemp:label({x=35, y=70, text=function() return (wgt.values.EscT_max_str or "--°c") end, font=FS.FONT_6, color=GREY})
    bTemp:arc({x=50, y=50, radius=g_rad, thickness=g_thick, startAngle=g_angel_min, endAngle=g_angel_max, color=lcd.RGB(0x222222)})
    -- bTemp:arc({x=50, y=50, radius=g_rad, thickness=g_thick, startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.EscT_max_percent) end, color=lcd.RGB(0x1F96C2), opacity=180})
    bTemp:arc({x=50, y=50, radius=gm_rad, thickness=gm_thick, startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.EscT_max_percent) end, color=lcd.RGB(0x1F96C2), opacity=180})
    bTemp:arc({x=50, y=50, radius=g_rad,  thickness=g_thick,  startAngle=g_angel_min, endAngle=function() return calEndAngle(wgt.values.EscT_percent)     end, color=lcd.RGB(0x1F96C2)})


    -- status bar
    local bStatusBar = pMain:box({x=0, y=wgt.zone.h-20})
    local statusBarColor = lcd.RGB(0x0078D4)
    bStatusBar:rectangle({x=0, y=0,w=wgt.zone.w, h=20, color=statusBarColor, filled=true})
    -- bStatusBar:label({x=3  , y=2, text=function() return string.format("RQLY: %s%%   RQLY-: %s", getValue("RQly"), getValue("RQly-")) end, font=FS.FONT_6, color=WHITE})
    bStatusBar:label({x=3  , y=2, text=function() return string.format("elrs min:%s%%", getValue("RQly-")) end, font=FS.FONT_6, color=WHITE})
    bStatusBar:label({x=170, y=2, text=function() return string.format("TPwr+: %smw", getValue("TPWR+")) end, font=FS.FONT_6, color=WHITE})
    -- bStatusBar:label({x=210, y=2, text=function() return string.format("Gov: %s", wgt.values.governor_str) end, font=FS.FONT_6, color=WHITE})
    bStatusBar:label({x=300, y=2, text=function() return string.format("Thr+: %s%%", wgt.values.thr_max) end, font=FS.FONT_6, color=WHITE})
    bStatusBar:label({x=380, y=2, text="VenbS & Shmuely", font=FS.FONT_6, color=YELLOW})

    -- image
    local isizew=200
    local isizeh=140
    local bImageArea = pMain:box({x=5, y=5, w=isizew, h=isizeh})
    local bRect = bImageArea:rectangle({x=0, y=0, w=isizew, h=isizeh, thickness=4, rounded=15, filled=false, color=GREY})
    local bImg = bImageArea:box({})
    wgt.values.img_box_2 = bImg
    wgt.values.img_replacment_area2 = bImageArea


    -- craft name
    local bCraftName = pMain:box({x=5, y=100})
    bCraftName:rectangle({x=10, y=17, w=isizew-20, h=25, filled=true, rounded=8, color=DARKGREY, opacity=200})
    bCraftName:label({text=function() return wgt.values.craft_name end,  x=15, y=15, font=FS.FONT_12 ,color=(wgt.options.guiStyle~=2 and WHITE or txtColor)})

    -- failed to arm flags
    local bNoConn = pMain:box({x=150, y=45, visible=function() return wgt.values.arm_fail end})
    bNoConn:rectangle({x=0, y=0, w=280, h=150, color=RED, filled=true, rounded=8, opacity=245})
    bNoConn:label({text=function() return wgt.values.arm_disable_flags_txt end, x=10, y=0, font=FS.FONT_8, color=WHITE})


    -- no connection
    local bNoConn = lvgl.box({x=0, y=0, visible=function() return wgt.is_connected==false end})
    -- bNoConn:label({x=100,  y=5,   text="Rotorflight Dashboard", font=FS.FONT_12, color=WHITE})
    local isizew=200
    local isizeh=140
    bNoConn:rectangle({x=5, y=5, w=isizew, h=isizeh, rounded=15, filled=true, color=BLACK, opacity=250})
    bNoConn:label({x=30, y=10, text=function() return wgt.not_connected_error end , font=FS.FONT_8, color=WHITE})
    bNoConn:image({x=50, y=30, w=110, h=110, file=baseDir.."widgets/img/no_connection_wr.png"})

end

-------------------------------------------------------------------
local function close()
    lvgl.confirm({title="Exit", message="exit config?",
        confirm=(function() lvgl.exitFullScreen() end)
    })
end

local function build_ui_appmode(wgt)
    lvgl.clear()
    local bMain = lvgl.box({x=0, y=0})
    bMain:label({text = app_name, x=140,y=10, color=WHITE, font=FS.FONT_12})

    local pg = lvgl.page({title="Rotorflight Dashboard", subtitle="Config",
        back=close,
        icon="/SCRIPTS/RF2_touch/widgets/img/rf2_logo.png",
        -- flexFlow=lvgl.FLOW_COLUMN,
        -- flexFlow=lvgl.FLOW_ROW,
        -- flexPad=30,
    })
    -- pg:rectangle({x=0, y=0, w=LCD_W, h=LCD_H, color=RED, filled=true, hide=false})

    -- pg:build({
    --     { type="setting", x=0, y=10, title="Craft Name (on FC)",
    --         children={
    --             { type="textEdit", x=150, y=0, w=180, maxLen=20,
    --                 value="sab goblin sport",
    --                 set=(function(val) txt=val end)
    --             },
    --             { type="button", text="reload", x=340, y=0, press=readCurrentBank},
    --             { type="button", text="Save", x=410, y=0, press=(function(wgt) readPids(wgt) end)},
    --         }
    --     }
    -- })

    pg:build({
        { type="setting", x=0, y=0, -- title="Craft Name (on FC)",
            children={
                { type="label", x=5, y=0,
                    text=function()
                        return string.format("Bank: %s", wgt.values.profile_id_str)
                    end,
                    font=BOLD
                },
                { type="button", text="read all pids", x=340, y=0, press=readPids},
            }
        }
    })


    -- pg:label({x=5, y=0, text=function() return string.format("PID list: %s", wgt.values.profile_id) end, font=BOLD})

    local bPidList = pg:box({x=0, y=50})
    local lineColor = lcd.RGB(0xCCCCCC)
    local pTitles = {"P", "I", "D", "F"}
    local axisTitles = {"roll", "pitch", "yaw"}
    for i=1, 6 do
        bPidList:label({x=80+(i-1)*60, y=0, text="bank " .. i})
        bPidList:vline({x=80-10 +(i-1)*60, y=5, h=360, w=1, color=lineColor})--, rounded=true})
    end

    for axis=1,3 do
        local h2 = (axis-1)*120+20
        -- bPidList:hline({x=50, y=h2+5, w=400, h=25, color=lineColor, rounded=true})
        bPidList:rectangle({x=40, y=h2, w=420, h=25, color=lineColor, filled=true, rounded=9})
        bPidList:label({x=200, y=h2, text=axisTitles[axis], font=BOLD})
        for p=1,4 do
            local h1 = h2 +(p-1)*20 +30
            bPidList:label({x=45, y=h1, text=pTitles[p]})
            for i=1, 6 do
                -- bPidList:rectangle({x=70+(i-1)*60, y=h1, w=60, h=25, color=RED, filled=false})
                bPidList:label({x=70+(i-1)*60, y=h1, w=60, text=function() return getPidValues(i, axis, p) end, font=function() return (i==wgt.values.profile_id) and BOLD or 0 end, align=CENTER})
            end
        end
    end
    -- bPidList:hline({x=50, y=25, w=400, h=1, color=lineColor})--, rounded=true})
    -- bPidList:vline({x=50-10 +(7-1)*70, y=5, h=110, w=1, color=lineColor})--, rounded=true})

end

-------------------------------------------------------------------

local replImg = 0
local imgTp = 0
local function updateCraftName(wgt)
    wgt.values.craft_name = wgt.mspTool.craftName()

    -- if (rf2.clock() - replImg > 5) then
    --     rf2.log("updateImage - interval")
    --     imgTp = imgTp + 1
    --     if imgTp % 2 == 0 then
    --         wgt.values.craft_name = "sab601"
    --     else
    --         wgt.values.craft_name = "sab588"
    --     end
    --     rf2.log("updateImage - newCraftName: %s", wgt.values.craft_name)
    --     replImg = rf2.clock()
    -- end
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
    wgt.values.rpm_str = string.format("%s",Hspd)
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
    local curr_top = wgt.options.currTop
    local curr = getValue("Curr")
    local curr_max = getValue("Curr+")
    if curr == 0 then
        curr = math.floor((rf2fc.msp.cache.mspBatteryState.batteryCurrent or 0) / 100)
        curr_max = math.max(curr_max, curr)
    end

    if rf2.runningInSimulator then
        curr = 90
        curr_max = 120
    end
    wgt.values.curr = curr
    wgt.values.curr_max = curr_max
    wgt.values.curr_percent = math.min(100, math.floor(100 * (curr / curr_top)))
    wgt.values.curr_max_percent = math.min(100, math.floor(100 * (curr_max / curr_top)))
    wgt.values.curr_str = string.format("%dA", wgt.values.curr)
    wgt.values.curr_max_str = string.format("+%dA", wgt.values.curr_max)

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
    wgt.values.capaPercent = math.floor(100 * (wgt.values.capaTotal - wgt.values.capaUsed) // wgt.values.capaTotal)
    local p = wgt.values.capaPercent
    if (p < 10) then
        wgt.values.capaColor = RED
    elseif (p < 30) then
        wgt.values.capaColor = ORANGE
    else
        wgt.values.capaColor = lcd.RGB(0x00963A) --GREEN
    end

    wgt.values.capaPercent_txt = string.format("%d%%", wgt.values.capaPercent)
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
    -- log("bb_percent: %s", wgt.values.bb_percent)
    -- log("bb_size: %s", wgt.values.bb_size)
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
    wgt.values.arm_fail = false

    if flagList ~= nil then
        -- log("disableFlags len: %s", #flagList)
        if (#flagList == 0) then
            wgt.values.arm_fail = false
        else
            wgt.values.arm_fail = true
            for i in pairs(flagList) do
                -- log("disableFlags: %s", i)
                -- log("disableFlags: %s", flagList[i])
                wgt.values.arm_disable_flags_txt = wgt.values.arm_disable_flags_txt .. flagList[i] .. "\n"
            end

        end
    end

end

local function updateThr(wgt)
    wgt.values.thr = getValue("Thr")
    wgt.values.thr_max = getValue("Thr+")
    -- local id = getSourceIndex("CH3") --????
    -- local val = (getValue(id)+1024)*100//2048
    -- wgt.values.thr_max = math.max(wgt.values.thr_max, val)
    if rf2.runningInSimulator then
        wgt.values.thr = 82
        wgt.values.thr_max = 96
    end
end

local function updateTemperature(wgt)
    local tempTop = wgt.options.tempTop

    wgt.values.EscT = getValue("EscT")
    wgt.values.EscT_max = getValue("EscT+")
    -- wgt.values.EscT = getValue("GSpd")
    -- wgt.values.EscT_max = getValue("GSpd+")
    if rf2.runningInSimulator then
        wgt.values.EscT = 60
        wgt.values.EscT_max = 75
    end
    wgt.values.EscT_str = string.format("%d°c", wgt.values.EscT)
    wgt.values.EscT_max_str = string.format("%d°c", wgt.values.EscT_max)

    wgt.values.EscT_percent = math.min(100, math.floor(100 * (wgt.values.EscT / tempTop)))
    wgt.values.EscT_max_percent = math.min(100, math.floor(100 * (wgt.values.EscT_max / tempTop)))
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

        -- local isizew=200
        -- local isizeh=140 --???
        -- wgt.values.img_replacment_area2:clear()
        -- wgt.values.img_replacment_area2:image({file=imageName, x=0, y=0, w=isizew, h=isizeh, fill=false})

        local isizew=160
        local isizeh=80 --???
        if wgt.values.img_box_1 then
            wgt.values.img_box_1:clear()
            wgt.values.img_box_1 = wgt.values.img_replacment_area1:box({})
            wgt.values.img_box_1:image({file=imageName, x=0, y=0, w=isizew, h=isizeh, fill=false})
        end

        local isizew=200
        local isizeh=140 --???
        if wgt.values.img_box_2 then
            wgt.values.img_box_2:clear()
            wgt.values.img_box_2 = wgt.values.img_replacment_area2:box({})
            wgt.values.img_box_2:image({file=imageName, x=0, y=0, w=isizew, h=isizeh, fill=false})
        end

        wgt.values.img_last_name = imageName
        wgt.values.img_craft_name_for_image = newCraftName
    end

end

---------------------------------------------------------------------------------------

local function update(wgt, options)
    log("update")
    if (wgt == nil) then return end
    wgt.options = options
    wgt.not_connected_error = "Not connected"

    log("wgt.options.guiStyle==%s", wgt.options.guiStyle)

    log("isFullscreen: %s", lvgl.isFullScreen())
    log("isAppMode: %s", lvgl.isAppMode())

    if lvgl.isFullScreen() then
        log("update: in app mode")
        build_ui_appmode(wgt)
    elseif wgt.options.guiStyle==3 then
        build_ui_modern(wgt)
    else
        build_ui(wgt)
    end
    return wgt
end

local function create(zone, options)
    wgt.zone = zone
    wgt.options = options
    return update(wgt, options)
end

local function background(wgt)
end

local function refresh(wgt, event, touchState)
    if (wgt == nil) then return end


    wgt.is_connected, wgt.not_connected_error = false, "no RF2_Server widget found"
    if rf2fc == nil then
        return
    else
        if rf2fc.mspCacheTools ~= nil then
            wgt.is_connected, wgt.not_connected_error = rf2fc.mspCacheTools.isCacheAvailable()
            if wgt.is_connected==false then
                return
            end
        end
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

    if (rf2.clock() - fanT1 > 0.1) then
        fan = fan + 1
        if fan > 10 then fan = 1 end
        fanT1 = rf2.clock()
    end

   dbgLayout()
end

return {create=create, update=update, background=background, refresh=refresh}
