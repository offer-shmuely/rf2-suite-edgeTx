local app_name = "rf2_dash"
local app_ver = "0.1"

local baseDir = "/SCRIPTS/RF2_touch/"
local inSimu = string.sub(select(2,getVersion()), -4) == "simu"

local timerNumber = 1

local err_img = bitmap.open(baseDir .. "widgets/img/no_connection_wr.png")
-- err_img = bitmap.resize(err_img, wgt.zone.w, wgt.zone.h)

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
-----------------------------------------------------------------------------------------------------------------

local function update(wgt, options)
    log("update")
    if (wgt == nil) then return end
    wgt.options = options
    log("update options: %s", tableToString(options))
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
    wgt.mspTool = rf2fc.mspCacheTools

    if is_avail == false then
        lcd.drawText(60 ,5, "Rotorflight Dashboard", FS.FONT_12 + WHITE)
        lcd.drawText(110 ,170, err, FS.FONT_8 + WHITE)
        lcd.drawBitmap(err_img, 150, 40)
        return
    end

    -- profile
    -- image /touch/images/pids.png
    lcd.drawText(0,0, "Bank", FS.FONT_6 + WHITE)
    lcd.drawText(6,10, string.format("%s", wgt.mspTool.profileId()), FS.FONT_16 + BLUE)

    -- rate
    -- image /touch/images/rates.png
    lcd.drawText(48,0,"Rate", FS.FONT_6 + WHITE)
    lcd.drawText(50,10,string.format("%s", wgt.mspTool.rateProfile()), FS.FONT_16 + ORANGE)

    -- time
    local t1 = model.getTimer(timerNumber - 1)
    local time_str, isNegative = formatTime(wgt, t1)
    lcd.drawText(140,50, time_str, FS.FONT_38 + WHITE)

    -- rpm
    local Hspd = getValue("Hspd")
    if inSimu then Hspd = 1800 end
    lcd.drawText(185+25,120, "RPM", FS.FONT_6 + WHITE)
    lcd.drawText(185, 130, string.format("%d",Hspd), FS.FONT_16 + WHITE)

    -- voltage
    x, y = 5, 55
    local vbat, vcel, batPercent
    if wgt.options.useTelemetry == 1 then
        vbat = inSimu and getValue("A1") or getValue("Vbat") -- ?
        vcel =  inSimu and getValue("A2") or getValue("Vcel") -- ?
        batPercent = inSimu and getValue("Tmp1") or getValue("Bat%")
        -- if inSimu then vcel = 3.6 end
    else
        vbat = (rf2fc.msp.cache.mspBatteryState.batteryVoltage or 0) / 100
        vcel = ((rf2fc.msp.cache.mspBatteryState.batteryVoltage or 0) / (rf2fc.msp.cache.mspBatteryConfig.batteryCellCount or 1)) / 100
        -- vcel = rf2fc.msp.cache.mspBatteryConfig.batteryCellCount
        batPercent = rf2fc.msp.cache.mspBatteryState.batteryPercentageRemaining or -1
    end

    log("vbat: %s, vcel: %s, BatPercent: %s", vbat, vcel, batPercent)
    local volt = (wgt.options.showTotalVoltage==1) and vbat or vcel
    lcd.drawText(x, y, "Cell", FS.FONT_6 + WHITE)
    -- lcd.drawText(x, y, string.format("Cell   %d%%", batPercent), FS.FONT_6 + WHITE)
    lcd.drawText(x, y+12, string.format("%.02fv",volt), FS.FONT_16 + WHITE)
    local percent = batPercent
    drawBlackboxHorz(wgt, {x=x, y=y+48,w=110,h=10,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=8, segments_h=20, cath=false}, percent,
        function()
            return (vcel < 3.7) and RED or GREEN
        end
    )
    lcd.drawText(90,85, string.format("%d%%", batPercent), FS.FONT_6 + WHITE)

    -- capacity
    x, y = 5, 140
    local capaTotal = rf2fc.msp.cache.mspBatteryConfig.batteryCapacity or -1
    local capaUsed = getValue("Capa")
    -- if wgt.options.useTelemetry == 1 then
    --     capaUsed = getValue("Capa")
    -- else
    --     if isSimu then
    --         capaUsed = math.floor(capaTotal / 2) or 0
    --     else
    --         capaUsed = 0
    --     end
    -- end
    local capaPercent = math.floor(100 * capaUsed / capaTotal)

    lcd.drawText(x, y -12, string.format("Capacity (Total: %s)", capaTotal), FS.FONT_6 + WHITE)
    drawBlackboxHorz(wgt, {x=x, y=y+5,w=110,h=35,segments_w=20, color=WHITE, bg_color=GREY, cath_w=10, cath_h=30, segments_h=20, cath=false}, capaPercent)
    lcd.drawText(x+25, y+2, string.format("%d%%",capaPercent), FS.FONT_16 + WHITE)

    -- current
    x, y = 350, 50
    local curr
    if wgt.options.useTelemetry == 1 then
        curr = getValue("Curr")
    else
        curr = math.floor((rf2fc.msp.cache.mspBatteryState.batteryCurrent or 0) / 100)
    end
    lcd.drawText(x, y, "Current", FS.FONT_6 + WHITE)
    local color = (curr < 100) and YELLOW or RED
    lcd.drawText(x, y+12, string.format("%d A", curr), FS.FONT_16 + color)

    -- rescue enabled?
    x, y = 350+20, 145
    local rescueOn = rf2fc.msp.cache.mspRescueProfile.mode == 1
    -- local rescueFlip = rf2fc.msp.cache.mspRescueProfile.flip_mode == 1
    local txt = rescueOn and "ON" or "OFF"
    -- if rescueOn then
    --     txt = string.format("%s (%s)", txt, (rescueFlip) and "Flip" or "No Flip")
    -- end

    lcd.drawText(x, y, "Rescue", FS.FONT_6 + WHITE)
    lcd.drawText(x, y+12, txt, FS.FONT_8 + WHITE)

    -- governor
    x, y = 10, 186
    if wgt.mspTool.governorEnabled() then
        lcd.drawText(x ,y,string.format("Using RF governor\nmode: %s", wgt.mspTool.governorMode()), FS.FONT_6 + WHITE)
    else
        lcd.drawText(x ,y,"governor  disabled", FS.FONT_6 + WHITE)
    end

    -- blackbox
    x, y = 350, 100
    if wgt.mspTool.blackboxEnable() then
        local blackboxInfo = wgt.mspTool.blackboxSize()
        local percent = 0
        if blackboxInfo.totalSize > 0 then
            percent = math.floor(100*blackboxInfo.usedSize/blackboxInfo.totalSize)
        end
        local size = math.floor(blackboxInfo.totalSize/ 1000000)
        -- local txt = string.format("Blackbox: %s%% %sGB", percent, size)
        local txt = string.format("Blackbox: %sGB", size)
        lcd.drawText(x, y, txt, FS.FONT_6 + WHITE)
        drawBlackboxHorz(wgt, {x=x,y=y+20,w=75,h=20,segments_w=10, color=WHITE, bg_color=GREY, cath_w=10, cath_h=80, segments_h=20, cath=false}, percent,
            function()
                return (percent>90) and RED or GREEN
            end
        )
        -- lcd.drawText(x+10, y+20, string.format("%s%% %sGB", percent, size), FS.FONT_8 + WHITE)
        lcd.drawText(x+25, y+20, string.format("%s%%", percent), FS.FONT_8 + WHITE)
    end


    -- craft name
    x,y = 160, 180
    lcd.drawText(x, y,"Heli Name", FS.FONT_6 + WHITE)
    lcd.drawText(x, y+15, wgt.mspTool.craftName(), FS.FONT_12 + ORANGE)
    -- lcd.drawText(dbgx, dbgy,"Heli: " .. wgt.mspTool.craftName(), FS.FONT_12 + ORANGE)

    -- arm
    x, y= 195, 10

    local armSwitchOn = wgt.mspTool.armSwitchOn()
    log("armSwitchOn %s:", armSwitchOn)
    local flagList = wgt.mspTool.armingDisableFlagsList()
    if flagList ~= nil then
        log("disableFlags len: %s", #flagList)
        if (#flagList == 0) then
            lcd.drawText(x, y,"ARM", FS.FONT_12 + RED)
        else
            lcd.drawText(x, y,"Not Arm", FS.FONT_12 + RED)
            y = y + 30
            for i in pairs(flagList) do
                log("disableFlags: %s", i)
                log("disableFlags: %s", flagList[i])
                lcd.drawFilledRectangle(x,y,130, 20, RED)
                lcd.drawText(x+5, y+1,flagList[i], FS.FONT_8 + WHITE)
                y = y + 25
            end

        end
    else
        log("disableFlags: no info")
    end


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

return {name=app_name, options=options, translate=translate, create=create, update=update, background=background, refresh=refresh}
