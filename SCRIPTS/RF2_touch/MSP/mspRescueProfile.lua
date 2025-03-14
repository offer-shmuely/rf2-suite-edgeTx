local function getRescueProfile(callback, callbackParam)
    local message = {
        command = 146, -- MSP_RESCUE_PROFILE
        processReply = function(self, buf)
            local config = {}
            --rf2.print("buf length: "..#buf)
            config.mode = { value = rf2.mspHelper.readU8(buf), min = 0, max = 1, table = { [0] = "Off", "On" } }
            config.flip_mode = { value = rf2.mspHelper.readU8(buf), min = 0, max = 1, table = { [0] = "No Flip", "Flip" } }
            config.flip_gain = { value = rf2.mspHelper.readU8(buf), min = 5, max = 250 }
            config.level_gain = { value = rf2.mspHelper.readU8(buf), min = 5, max = 250 }
            config.pull_up_time = { value = rf2.mspHelper.readU8(buf), min = 0, max = 250, scale = 10 }
            config.climb_time = { value = rf2.mspHelper.readU8(buf), min = 0, max = 250, scale = 10 }
            config.flip_time = { value = rf2.mspHelper.readU8(buf), min = 0, max = 250, scale = 10 }
            config.exit_time = { value = rf2.mspHelper.readU8(buf), min = 0, max = 250, scale = 10 }
            config.pull_up_collective = { value = rf2.mspHelper.readU16(buf), min = 0, max = 1000, mult = 10, scale = 10 }
            config.climb_collective = { value = rf2.mspHelper.readU16(buf), min = 0, max = 1000, mult = 10, scale = 10 }
            config.hover_collective = { value = rf2.mspHelper.readU16(buf), min = 0, max = 1000, mult = 10, scale = 10 }
            config.hover_altitude = { value = rf2.mspHelper.readU16(buf), min = 0, max = 10000, mult = 10, scale = 100 }
            config.alt_p_gain = { value = rf2.mspHelper.readU16(buf), min = 0, max = 10000 }
            config.alt_i_gain = { value = rf2.mspHelper.readU16(buf), min = 0, max = 10000 }
            config.alt_d_gain = { value = rf2.mspHelper.readU16(buf), min = 0, max = 10000 }
            config.max_collective = { value = rf2.mspHelper.readU16(buf), min = 1, max = 1000, mult = 10, scale = 10 }
            config.max_setpoint_rate = { value = rf2.mspHelper.readU16(buf), min = 1, max = 1000, mult = 10 }
            config.max_setpoint_accel = { value = rf2.mspHelper.readU16(buf), min = 1, max = 10000, mult = 10 }

            rf2.log("Processing rescue profile reply...")
            rf2.log("mode: %d", config.mode.value)
            rf2.log("flip_mode: %d", config.flip_mode.value)
            rf2.log("flip_gain: %d", config.flip_gain.value)
            rf2.log("level_gain: %d", config.level_gain.value)
            rf2.log("pull_up_time: %d", config.pull_up_time.value)
            rf2.log("climb_time: %d", config.climb_time.value)
            rf2.log("flip_time: %d", config.flip_time.value)
            rf2.log("exit_time: %d", config.exit_time.value)
            rf2.log("pull_up_collective: %d", config.pull_up_collective.value)
            rf2.log("climb_collective: %d", config.climb_collective.value)
            rf2.log("hover_collective: %d", config.hover_collective.value)
            rf2.log("hover_altitude: %d", config.hover_altitude.value)
            rf2.log("alt_p_gain: %d", config.alt_p_gain.value)
            rf2.log("alt_i_gain: %d", config.alt_i_gain.value)
            rf2.log("alt_d_gain: %d", config.alt_d_gain.value)
            rf2.log("max_collective: %d", config.max_collective.value)
            rf2.log("max_setpoint_rate: %d", config.max_setpoint_rate.value)
            rf2.log("max_setpoint_accel: %d", config.max_setpoint_accel.value)
            
            callback(callbackParam, config)
        end,
        simulatorResponse = { 1, 0, 200, 100, 5, 3, 10, 5, 182, 3, 188, 2, 194, 1, 244, 1, 20, 0, 20, 0, 10, 0, 232, 3, 44, 1, 184, 11 }
    }
    rf2.mspQueue:add(message)
end

local function setRescueProfile(config)
    local message = {
        command = 147, -- MSP_SET_RESCUE_PROFILE
        payload = {},
        simulatorResponse = {}
    }
    rf2.mspHelper.writeU8(message.payload, config.mode.value)
    rf2.mspHelper.writeU8(message.payload, config.flip_mode.value)
    rf2.mspHelper.writeU8(message.payload, config.flip_gain.value)
    rf2.mspHelper.writeU8(message.payload, config.level_gain.value)
    rf2.mspHelper.writeU8(message.payload, config.pull_up_time.value)
    rf2.mspHelper.writeU8(message.payload, config.climb_time.value)
    rf2.mspHelper.writeU8(message.payload, config.flip_time.value)
    rf2.mspHelper.writeU8(message.payload, config.exit_time.value)
    rf2.mspHelper.writeU16(message.payload, config.pull_up_collective.value)
    rf2.mspHelper.writeU16(message.payload, config.climb_collective.value)
    rf2.mspHelper.writeU16(message.payload, config.hover_collective.value)
    rf2.mspHelper.writeU16(message.payload, config.hover_altitude.value)
    rf2.mspHelper.writeU16(message.payload, config.alt_p_gain.value)
    rf2.mspHelper.writeU16(message.payload, config.alt_i_gain.value)
    rf2.mspHelper.writeU16(message.payload, config.alt_d_gain.value)
    rf2.mspHelper.writeU16(message.payload, config.max_collective.value)
    rf2.mspHelper.writeU16(message.payload, config.max_setpoint_rate.value)
    rf2.mspHelper.writeU16(message.payload, config.max_setpoint_accel.value)
    rf2.mspQueue:add(message)
end

return {
    getRescueProfile = getRescueProfile,
    setRescueProfile = setRescueProfile
}
