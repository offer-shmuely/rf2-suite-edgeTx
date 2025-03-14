local app_name = "rf2_image"
local app_ver = "0.4"

local NA_IMAGE_NAME = "img/rf2_image_def.png"

local options = {}
local is_first_time = true

local function log(fmt, ...)
    print(string.format("[%s] "..fmt, app_name, ...))
end

local function fileExists(name)
    local f = io.open(name, "r")
    if f then
        io.close(f)
        return true
    end
    return false
end


local function update(wgt, options)
    if (wgt == nil) then return end
    wgt.options = options
    wgt.last_craftName = nil
    wgt.last_image_name = nil
    wgt.is_image_exist = nil
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options
    }
    update(wgt, options)
    return wgt
end

local function background(wgt)
end

-- local t1 = getTime() / 100

local function getCraftNameFromMsp(wgt)
    local is_avail = false
    if rf2fc ~= nil and rf2fc.mspCacheTools ~= nil then
        is_avail, err = rf2fc.mspCacheTools.isCacheAvailable()
    end

    -- local t2 = getTime() / 100
    -- if (t2 - t1) > 10 then
    --     return "sab570"
    -- end

    local craftName
    if is_avail == true then
        -- log("msp cache is available")
        wgt.mspTool = rf2fc.mspCacheTools
        craftName = wgt.mspTool.craftName()
        return craftName
    else
        log("msp cache is NOT available")
        return nil
    end
end

local function loadImage(wgt, craftName)
    -- local imageName = craftName~=nil and "/IMAGES/" .. craftName .. ".png" or "---"
    local imageName = "/IMAGES/" .. craftName .. ".png"
    wgt.last_image_name = imageName

    if fileExists(imageName) then
        wgt.is_image_exist = true
    else
        log("Failed to load image for model: %s=%s", craftName, imageName)
        imageName = NA_IMAGE_NAME
        wgt.is_image_exist = false
    end

    wgt.img = bitmap.open(imageName)
    wgt.img = bitmap.resize(wgt.img, wgt.zone.w,wgt.zone.h)

    wgt.last_craftName = craftName
    log("Loaded image for model: %s=%s", craftName, imageName)
    collectgarbage()
end
---------------------------------------------------------------------------------------------------

local function refresh(wgt, event, touchState)
    if (wgt == nil) then return end
    if (wgt.options == nil) then return end

    local newCraftName = getCraftNameFromMsp(wgt)
    -- log("newCraftName: %s", newCraftName)

    if newCraftName == nil then
        if wgt.last_craftName==nil then
            newCraftName = wgt.last_craftName
        end
    end

    if newCraftName == nil then
        newCraftName = "---"
    end

    if newCraftName ~= wgt.last_craftName then
        log("model changed, %s --> %s", wgt.last_craftName, newCraftName)
        loadImage(wgt, newCraftName)
    end

    lcd.drawBitmap(wgt.img, 0, 0)
    if wgt.last_craftName == "---" then
        lcd.drawText(0, 0, "No connection, so not image", 0 + GREY + BLINK)
    elseif wgt.is_image_exist == false then
        lcd.drawText(0, 0, string.format("No Image for: [%s]", wgt.last_craftName), 0 + BOLD + RED + BLINK)
        lcd.drawText(0, 20, wgt.last_image_name, SMLSIZE)
    end

end

return {name=app_name, options=options, create=create, update=update, background=background, refresh=refresh}
