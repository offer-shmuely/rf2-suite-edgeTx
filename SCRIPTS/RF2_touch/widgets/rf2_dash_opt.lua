local M = {

    options = {
        {"showTotalVoltage", BOOL  , 0      }, -- 0=Show as average Lipo cell level, 1=show the total voltage (voltage as is)
        -- {"enableCapa", BOOL, 1 },
        -- {"useTelemetry", BOOL, 1 },
        },

    translate = function(name)
        local translations = {
            showTotalVoltage="Show Total Voltage",
            -- enableCapa="Enable Capacity",
            -- useTelemetry="Use Telemetry (faster update)",
        }
        return translations[name]
    end

}

return M
