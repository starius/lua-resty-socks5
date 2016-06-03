local ngx = require('ngx')

local socks5 = {}

local char = string.char

-- magic numbers
local SOCKS5 = 0x05
local NUMBER_OF_AUTH_METHODS = 0x01
local NO_AUTHENTICATION = 0x00
local TCP_CONNECTION = 0x01
local RESERVED = 0x00
local IPv4 = 0x01
local DOMAIN_NAME = 0x03
local IPv6 = 0x04

local REQUEST_GRANTED = 0x00
local CONN_ERRORS = {
    [0x01] = 'general failure',
    [0x02] = 'connection not allowed by ruleset',
    [0x03] = 'network unreachable',
    [0x04] = 'host unreachable',
    [0x05] = 'connection refused by destination host',
    [0x06] = 'TTL expired',
    [0x07] = 'command not supported / protocol error',
    [0x08] = 'address type not supported',
}

local CHUNK_SIZE = 1024

-- authentication to socks5 server
socks5.auth = function(cosocket)
    cosocket:send(char(SOCKS5, NUMBER_OF_AUTH_METHODS,
        NO_AUTHENTICATION))
    local auth_response = cosocket:receive(2)
    if auth_response ~= char(SOCKS5, NO_AUTHENTICATION) then
        return nil, "Socks5 authentification failed"
    end
    return true
end

-- connection request
socks5.connect = function(cosocket, host, port)
    local host_length = #host
    local port_big_endian = char(
        math.floor(port / 256), port % 256)
    cosocket:send(char(SOCKS5, TCP_CONNECTION, RESERVED,
        DOMAIN_NAME, host_length) .. host .. port_big_endian)
    local conn_response = cosocket:receive(3)
    if conn_response ~=
            char(SOCKS5, REQUEST_GRANTED, RESERVED) then
        local status = conn_response:byte(2)
        local message = CONN_ERRORS[status] or 'Unknown error'
        return nil, message
    end
    -- pop address
    local addr_type = cosocket:receive(1)
    if addr_type == char(DOMAIN_NAME) then
        local addr_length = addr_type:byte(1)
        cosocket:receive(addr_length)
    elseif addr_type == char(IPv4) then
        cosocket:receive(4)
    elseif addr_type == char(IPv6) then
        cosocket:receive(16)
    else
        return nil, 'Bad address type: ' .. string.byte(addr_type)
    end
    -- pop port
    cosocket:receive(2)
    return true
end

socks5.handle_request = function(socks5host, socks5port,
        request_changer, response_changer, change_only_html)
    local sosocket = ngx.socket.connect(socks5host, socks5port)
    do
        local status, message = socks5.auth(sosocket)
        if not status then
            ngx.say('Error: ' .. message)
            return
        end
    end
    local target_host = ngx.req.get_headers()['Host']
    if request_changer then
        target_host = request_changer(target_host)
    end
    local target_port = 80
    do
        local status, message = socks5.connect(sosocket,
            target_host, target_port)
        if not status then
            ngx.say('Error: ' .. message)
            return
        end
    end
    -- read request
    local clheader = ngx.req.raw_header()
    if request_changer then
        clheader = request_changer(clheader)
    end
    sosocket:send(clheader)
    ngx.req.read_body()
    local clbody = ngx.req.get_body_data()
    if clbody then
        if request_changer then
            clbody = request_changer(clbody)
        end
        sosocket:send(clbody)
    end
    -- read response
    local soheader, message =
        sosocket:receiveuntil('\r\n\r\n')()
    if not soheader then
        ngx.say('No headers received from target: ' .. message)
        return
    end
    local sobody_length = soheader:match(
        'Content%-Length%: (%d+)')
    local is_html = soheader:match('Content%-Type: text/html')
    local change = is_html or not change_only_html
    local clsocket = ngx.req.socket(true)
    if response_changer and change then
        -- read whole body
        local sobody = sosocket:receive(sobody_length or '*a') or ''
        sobody = response_changer(sobody)
        soheader = response_changer(soheader)
        if soheader:find('Content%-Length%:') then
            soheader = soheader:gsub('Content%-Length%: %d+',
                'Content-Length: ' .. #sobody)
        else
            soheader = soheader ..
                '\r\nContent-Length: ' .. #sobody
        end
        clsocket:send(soheader .. '\r\n\r\n' .. sobody)
    else
        -- stream
        clsocket:send(soheader .. '\r\n\r\n')
        while true do
            local sobody, _, partial = sosocket:receive(CHUNK_SIZE)
            if not sobody then
                clsocket:send(partial)
                break
            end
            local bytes = clsocket:send(sobody)
            if not bytes then
                break
            end
        end
    end
    -- close
    sosocket:close()
end

return socks5

