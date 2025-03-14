local toolName = "TNS|_RF2 Touch (touch disabled)|TNE"

--local function run()
--    return "/SCRIPTS/RF2_touch/tool_touch_disabled.lua"
--end

--return { run = run }


chdir("/SCRIPTS/RF2_touch")
local tool = assert(loadScript("tool.lua"))(false)
return { run = tool.run }
