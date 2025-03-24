local allow_touch_app = ...
-- to disable touch app, and use the text line version. set to false
-- allow_touch_app = false

local LUA_VERSION = "2.1.21"
local baseDir = "/SCRIPTS/RF2_touch/"
--chdir(baseDir)

local function select_ui()
    if allow_touch_app == false then
        return "ui.lua"
    end

    local ver, radio, maj, minor, rev, osname = getVersion()

    local isTouch = (osname=="EdgeTX") and (LCD_W==480) and (LCD_H==272 or LCD_H==320) and (maj==2) and (minor>=9)
    if isTouch then
        return "touch/ui_touch.lua"
    end

    return "ui.lua"
end

local run = nil
local scriptsCompiled = assert(loadScript(baseDir.."COMPILE/scripts_compiled.lua"))()

local stick_ail_val = getValue('ail')
local stick_ele_val = getValue('ele')
local force_recompile        = (stick_ail_val > 1000) and (stick_ele_val >  1000)
local enable_serial_debug    = (stick_ail_val > 1000) and (stick_ele_val < -1000)

if scriptsCompiled and force_recompile==false then
    assert(loadScript(baseDir.."rf2_init.lua"))(baseDir)
    rf2.radio = assert(rf2.loadScript("radios.lua"))()

    rf2.enable_serial_debug = enable_serial_debug
    local ui_file = select_ui()
    run = assert(rf2.loadScript(ui_file))(LUA_VERSION)
else
    run = assert(loadScript(baseDir.."COMPILE/compile.lua"))()
    collectgarbage()
end

return { run = run }
