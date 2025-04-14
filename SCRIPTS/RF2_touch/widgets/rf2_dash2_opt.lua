local M = {

    options = {
        {"showTotalVoltage", BOOL  , 0      }, -- 0=Show as average Lipo cell level, 1=show the total voltage (voltage as is)
        -- {"enableCapa", BOOL, 1 },
        -- {"useTelemetry", BOOL, 1 },
        -- {"guiStyle", CHOICE, 1 , {"Fancy", "Less Colors", "Modern"} },
        {"guiStyle", VALUE, 1 , 1,3 },
        {"currTop", VALUE, 150 , 40,300 },
        {"tempTop", VALUE,  90 , 30,150 },
    },

    translate = function(name)
        local translations = {
            showTotalVoltage="Show Total Voltage",
            -- enableCapa="Enable Capacity",
            -- useTelemetry="Use Telemetry (faster update)",
            guiStyle="GUI Style",
            currTop="Max Current",
            tempTop="Max ESC Temp",
        }
        return translations[name]
    end

}

return M
