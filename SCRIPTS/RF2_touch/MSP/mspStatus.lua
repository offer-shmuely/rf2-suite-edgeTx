local function getStatus(callback, callbackParam)
    local message = {
        command = 101, -- MSP_STATUS
        processReply = function(self, buf)
            local status = {}
            -- offset 1: PID task delta time
            --status.pidCycleTime = rf2.mspHelper.readU16(buf)
            -- offset 3: Gyro task delta time
            --status.gyroCycleTime = rf2.mspHelper.readU16(buf)
            -- offset 5: Sensor status
            buf.offset = 7
            status.flightModeFlags = rf2.mspHelper.readU32(buf)
            -- rf2.print("msp flightModeFlags: "..tostring(status.flightModeFlags))

            -- offset 11: Profile number (compatibility)
            buf.offset = 12
            status.realTimeLoad = rf2.mspHelper.readU16(buf)
            -- rf2.print("Real-time load: "..tostring(status.realTimeLoad))
            status.cpuLoad = rf2.mspHelper.readU16(buf)
            -- rf2.print("CPU load: "..tostring(status.cpuLoad))
            -- offset 16: Extra flight mode flags count (compatibility)
            -- offset 17: Arming disable flags count
            buf.offset = 18
            status.armingDisableFlags = rf2.mspHelper.readU32(buf)
            --rf2.print("Arming disable flags: "..tostring(status.armingDisableFlags))
            -- offset 22: Reboot required
            -- offset 23: Configuration state
            buf.offset = 24
            status.profile = rf2.mspHelper.readU8(buf)
            -- offset 25: PID profile count
            --rf2.print("Profile: "..tostring(status.profile+1))
            --status.numProfiles = rf2.mspHelper.readU8(buf)
            buf.offset = 26
            status.rateProfile = rf2.mspHelper.readU8(buf)
            -- rf2.print("rateProfile: "..tostring(status.rateProfile+1))
            --status.numRateProfiles = rf2.mspHelper.readU8(buf)
            --status.motorCount = rf2.mspHelper.readU8(buf)
            --rf2.print("Number of motors: "..tostring(status.motorCount))
            --status.servoCount = rf2.mspHelper.readU8(buf)
            --rf2.print("Number of servos: "..tostring(status.servoCount))
            -- offset 30: Gyro detection flags
            callback(callbackParam, status)


-- offset list with remarks for the selected command in msp.c:

-- offset 1: PID task delta time
-- offset 3: Gyro task delta time
-- offset 5: Sensor status
-- offset 7: Flight mode flags
-- offset 11: Profile number (compatibility)
-- offset 12: Maximum real-time load
-- offset 14: Average CPU load
-- offset 16: Extra flight mode flags count (compatibility)
-- offset 17: Arming disable flags count
-- offset 18: Arming disable flags
-- offset 22: Reboot required
-- offset 23: Configuration state
-- offset 24: Current PID profile index
-- offset 25: PID profile count
-- offset 26: Current control rate profile index
-- offset 27: Control rate profile count
-- offset 28: Motor count
-- offset 29: Servo count (if applicable)
-- offset 30: Gyro detection flags

        end,
        simulatorResponse = {
            240, 1, 124, 0, -- Header
            35, 0, 0, 0,    -- flightModeFlags (0x00000023)
            224, 1,         -- realTimeLoad (0x01E0)
            10, 1,          -- cpuLoad (0x010A)
            0,              -- Extra flight mode flags count (compatibility)
            26, 0, 0, 0,    -- armingDisableFlags (0x001A0000)
            0,              -- profile (0x00)
            2,              -- rateProfile (0x02)
            1,              -- Reboot required
            6,              -- Configuration state
            2,              -- Current PID profile index
            6,              -- PID profile count
            1,              -- Current control rate profile index
            4,              -- Control rate profile count
            1               -- Gyro detection flags
        }
    }

    rf2.mspQueue:add(message)
end

return {
    getStatus = getStatus
}
