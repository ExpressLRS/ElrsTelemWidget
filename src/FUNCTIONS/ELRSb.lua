-- TNS|ELRS Bind|TNE
return { run = function (event)
    local CRSF_FRAMETYPE_PARAMETER_WRITE = 0x2D
    local CRSF_FRAMETYPE_ELRS_STATUS = 0x2E
    local CRSF_FRAMETYPE_COMMAND = 0x32
    local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA
    local CRSF_ADDRESS_CRSF_RECEIVER = 0xEC
    local CRSF_ADDRESS_CRSF_TRANSMITTER = 0xEE
    local CRSF_ADDRESS_ELRS_LUA = 0xEF
    local CRSF_COMMAND_SUBCMD_RX = 0x10
    local CRSF_COMMAND_SUBCMD_RX_BIND = 0x01

    local isConnected = function ()
        crossfireTelemetryPush(CRSF_FRAMETYPE_PARAMETER_WRITE,
            { CRSF_ADDRESS_CRSF_TRANSMITTER, CRSF_ADDRESS_ELRS_LUA, 0x00, 0x00 }) 

        -- Poll for up to 0.1s for a elrs TX state response
        local start = getTime()
        while getTime() - start < 10 do
            local command, data = crossfireTelemetryPop()
            if command == CRSF_FRAMETYPE_ELRS_STATUS then
                -- IsConnected is the low bit of the flags byte
                return data[2] == CRSF_ADDRESS_CRSF_TRANSMITTER
                    and bit32.btest(data[6], 1)
            end
        end
    end

    local dest = isConnected() and CRSF_ADDRESS_CRSF_RECEIVER or CRSF_ADDRESS_CRSF_TRANSMITTER
    crossfireTelemetryPush(CRSF_FRAMETYPE_COMMAND,
        { dest, CRSF_ADDRESS_RADIO_TRANSMITTER, CRSF_COMMAND_SUBCMD_RX, CRSF_COMMAND_SUBCMD_RX_BIND }
    )
    return 1
end }
