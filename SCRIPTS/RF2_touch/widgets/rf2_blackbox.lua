local app_name = "rf2_blackbox"

local baseDir = "/SCRIPTS/RF2_touch/"

--------------------------------------------------------------
local function log(fmt, ...)
    print(string.format("[%s] "..fmt, app_name, ...))
    return
end
--------------------------------------------------------------

-- better font size names
local FS={FONT_38=XXLSIZE,FONT_16=DBLSIZE,FONT_12=MIDSIZE,FONT_8=0,FONT_6=SMLSIZE}

-----------------------------------------------------------------------------------------------------------------

local function update(wgt, options)
    log("update")
    if (wgt == nil) then return end
    wgt.options = options

    wgt.values = {
        bb_enabled = true,
        bb_percent = 0,
        bb_size = 0,
        bb_txt = "Blackbox: --% 0MB",
    }

    return wgt
end

local function create(zone, options)
    local wgt = {

    }
    wgt.zone = zone
    wgt.options = options
    return update(wgt, options)
end
-----------------------------------------------------------------------------------------------------------------

local mspCache_blackboxEnable = function() return rf2fc.msp.cache.mspDataflash.ready==true and rf2fc.msp.cache.mspDataflash.supported==true end
local mspCache_blackboxSize = function()
    if rf2fc.msp.cache.mspDataflash.ready ~= true then
        return { enabled=false, totalSize=0, usedSize=0, freeSize=0 }
    end
    return { enabled=mspCache_blackboxEnable(), totalSize= rf2fc.msp.cache.mspDataflash.totalSize, usedSize= rf2fc.msp.cache.mspDataflash.usedSize, freeSize= rf2fc.msp.cache.mspDataflash.totalSize - rf2fc.msp.cache.mspDataflash.usedSize }
end

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
    if myBatt.text then
        lcd.drawText(myBatt.w/2 -10, myBatt.y+myBatt.h/2 -10, myBatt.text, LEFT + FS.FONT_8 + (myBatt.text_color or WHITE))
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


local function background(wgt)
end

local function refresh(wgt)
    local is_avail, err = false, "no RF2_Server widget found"
    if rf2fc ~= nil and rf2fc.mspCacheTools ~= nil then
        is_avail, err = rf2fc.mspCacheTools.isCacheAvailable()
    end
    if is_avail == false then
        lcd.drawText(10 ,0, err, FS.FONT_8 + RED)
        return
    end
    wgt.mspTool = rf2fc.mspCacheTools


    updateBB(wgt)

    log("blackboxInfo: %s%% / %s MB", wgt.values.bb_percent, wgt.values.bb_size)

    local isOnTop = wgt.zone.h < 60 and wgt.zone.w < 120
    local myBB
    if isOnTop then
        lcd.drawText(0,0, "Blackbox", FS.FONT_6 + wgt.options.text_color)
        myBB = {x=0,y=20, w=60, h=wgt.zone.h-30, segments_w=5, color=WHITE, cath_w=26, cath_h=10, segments_h=20 }
    else
        lcd.drawText(15,0, "Blackbox:", FS.FONT_8 + wgt.options.text_color)
        lcd.drawText(15,20, string.format("Used: %s%% / %s MB", wgt.values.bb_percent, wgt.values.bb_size), FS.FONT_8 + wgt.options.text_color)
        myBB = {x=10,y=50,w=wgt.zone.w-20, h=30, segments_w=5, color=WHITE, cath_w=26, cath_h=10, segments_h=20,
            text=string.format("%s%%", wgt.values.bb_percent),
        }
    end


    drawBlackboxHorz(
        wgt,
        myBB,
        wgt.values.bb_percent,
        function()
            return wgt.values.bbColor
        end
    )

end

return {name=app_name, create=create, update=update, background=background, refresh=refresh}
