local monitor = peripheral.find("monitor")
local protocol = "CBCNetWork"
peripheral.find("modem", rednet.open)
monitor.clear()
monitor.setTextScale(1)

local properties = {
    cannonID = 1
}

local location = {
    x = 0,
    y = 0,
    z = 0
}

local newdigits = function ()
    return {0, 0, 0, 0, 0}
end


local refreshScreen = function ()
    local templocation = {
        x = string.gsub(tostring(location.x), "[^%w]", ""),
        y = string.gsub(tostring(location.y), "[^%w]", ""),
        z = string.gsub(tostring(location.z), "[^%w]", "")
    }
    for k, v in pairs(templocation) do
        if #v < 5 then
            templocation[k] = string.rep("0", 5 - #v) .. v
        end
    end
    monitor.setCursorPos (1, 1)
    monitor.blit("  +++++", "00fffff", "ff00000")
    monitor.setCursorPos (1, 2)
    if location.x >=0 then
        monitor.write("X+")
    else
        monitor.write("X-")
    end

    monitor.setCursorPos (3, 2)
    monitor.write(templocation.x)
    monitor.setCursorPos (1, 3)
    monitor.blit("  -----", "00fffff", "ff00000")

    monitor.setCursorPos (1, 4)
    monitor.blit("  +++++", "00fffff", "ff00000")
    monitor.setCursorPos (1, 5)
    if location.y >=0 then
        monitor.write("Y+")
    else
        monitor.write("Y-")
    end
    monitor.setCursorPos (3, 5)
    monitor.write(templocation.y)
    monitor.setCursorPos (1, 6)
    monitor.blit("  -----", "00fffff", "ff00000")

    monitor.setCursorPos (1, 7)
    monitor.blit("  +++++", "00fffff", "ff00000")
    monitor.setCursorPos (1, 8)
    if location.z >=0 then
        monitor.write("Z+")
    else
        monitor.write("Z-")
    end
    monitor.setCursorPos (3, 8)
    monitor.write(templocation.z)
    monitor.setCursorPos (1, 9)
    monitor.blit("  -----", "00fffff", "ff00000")
end

local touchScren = function ()
    refreshScreen()
    local xdigits = newdigits()
    local ydigits = newdigits()
    local zdigits = newdigits()
    local isNagative = {
            x = false,
            y = false,
            z = false
        }
    print (xdigits[1])
    while true do
        local x, y = 0, 0
        local event, side, x, y = os.pullEvent ("monitor_touch")
        local xdig = x - 2
        if xdig>=1 and xdig <=5 then
            if y == 1 then
                xdigits[xdig] = (xdigits[xdig] + 1) % 10
            elseif y == 3 then
                xdigits[xdig] = (xdigits[xdig] - 1) % 10
            elseif y == 4 then
                ydigits[xdig] = (ydigits[xdig] + 1) % 10
            elseif y == 6 then
                ydigits[xdig] = (ydigits[xdig] - 1) % 10
            elseif y == 7 then
                zdigits[xdig] = (zdigits[xdig] + 1) % 10
            elseif y == 9 then
                zdigits[xdig] = (zdigits[xdig] - 1) % 10
            end
        elseif xdig == 0 then
            if y==2 then
                isNagative.x = not isNagative.x
            elseif y==5 then
                isNagative.y = not isNagative.y
            elseif y==8 then
                isNagative.z = not isNagative.z
            end
        end
        if isNagative.x then
            location.x = -tonumber(table.concat(xdigits))
        else
            location.x = tonumber(table.concat(xdigits))
        end
        if isNagative.y then
            location.y = -tonumber(table.concat(ydigits))
        else
            location.y = tonumber(table.concat(ydigits))
        end
        if isNagative.z then
            location.z = -tonumber(table.concat(zdigits))
        else
            location.z = tonumber(table.concat(zdigits))
        end
        --[[
        location.x = tonumber(table.concat(xdigits))
        location.y = -tonumber(table.concat(ydigits))
        location.z = tonumber(table.concat(zdigits))
        --]]
        refreshScreen()
        print(tonumber(table.concat(xdigits)))
        print(tonumber(table.concat(ydigits)))
    end
end

local listen_send = function ()
    while true do
        rednet.send(properties.cannonID, location, protocol)
        sleep(0.05)
    end
    
end



parallel.waitForAll(touchScren, listen_send)