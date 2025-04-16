local app_name = "rf2_dash2"
local widg_dir = "/SCRIPTS/RF2_touch/widgets/"
chdir(widg_dir)
local tool = nil
local tool_opt = loadScript(widg_dir..app_name .. "_opt.lua", "tcd")()

local function create(zone, options)
    tool = assert(loadScript(widg_dir..app_name .. ".lua", "tcd"))()
    return tool.create(zone, options)
end
local function update(wgt, options) return tool.update(wgt, options) end
local function refresh(wgt)         return tool.refresh(wgt)    end
local function background(wgt)      return tool.background(wgt) end

return {name=app_name, options=tool_opt.options, translate=tool_opt.translate, create=create, update=update, refresh=refresh, background=background, useLvgl = true}
