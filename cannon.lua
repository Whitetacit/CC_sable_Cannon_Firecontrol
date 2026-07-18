local  monitor  =  peripheral.find ( "monitor" ) 
monitor.setTextScale(0.5)
peripheral.find("modem", rednet.open)
local protocol, request_protocol = "CBCNetWork", "CBCcenter"


local properties = {
    barrelLength = "5",
    velocity = "160",
    drag = "0.01",
    gravity = "0.05",
    max_rotate_speed = 256,
    YawBearID = "6",
    PitchBearID = "7",
    controlCenterId = "9",
    forecastRot = "8",
    forecastMov = "12",
    cannonOffset = {
            x = 0,
            y = 0,
            z = 0
        }
}

local newVec = function() --坐标表格定义
    return {
        x = 0,
        y = 0,
        z = 0
    }
end

local newQuat = function ()--四元数定义
    return {
        w = 1,
        x = 0,
        y = 0,
        z = 0
    }
end

local cannonAtt = {
    locate = newVec(),
    pose = newQuat()
}

local parent = {
    pos = newVec(),
    quat = newQuat(),
    omega = newVec(),
    velocity = newVec()
}

local pitchParent = {
    slug = ""
}

function cannonAtt:getAtt() --获取大炮位置
    local table_pose = sublevel.getLogicalPose ()
    local pose = table_pose["position"]
    local orientation = table_pose["orientation"]
    local orientationV = orientation["v"]
    self.locate = {
        x = pose["x"],
        y = pose["y"],
        z = pose["z"]
    }
    self.pose = {
        w = orientation["a"],
        x = orientationV["x"],
        y = orientationV["y"],
        z = orientationV["z"]
    }
    
end

local getBearId = function ()--电脑id检测
    local YawId = #properties.YawBearID == 0 and 0 or tonumber(properties.YawBearID)
    local PitchId = #properties.PitchBearID == 0 and 0 or tonumber(properties.PitchBearID)
    YawId = YawId and YawId or 0
    PitchId = PitchId and PitchId or 0
    return YawId, PitchId
end

local ln = function(x)
    return math.log(x) / math.log(math.exp(1))
end

function math.lerp(a, b, t)
    return a + (b - a) * t
end

local copysign = function(num1, num2)
    num1 = math.abs(num1)
    num1 = num2 > 0 and num1 or -num1
    return num1
end

local RotateVectorByQuat = function(quat, v)
    local x = quat.x * 2
    local y = quat.y * 2
    local z = quat.z * 2
    local xx = quat.x * x
    local yy = quat.y * y
    local zz = quat.z * z
    local xy = quat.x * y
    local xz = quat.x * z
    local yz = quat.y * z
    local wx = quat.w * x
    local wy = quat.w * y
    local wz = quat.w * z
    local res = {}
    res.x = (1.0 - (yy + zz)) * v.x + (xy - wz) * v.y + (xz + wy) * v.z
    res.y = (xy + wz) * v.x + (1.0 - (xx + zz)) * v.y + (yz - wx) * v.z
    res.z = (xz - wy) * v.x + (yz + wx) * v.y + (1.0 - (xx + yy)) * v.z
    return res
end

local quatMultiply = function(q1, q2)
    local newQuat = {}
    newQuat.w = -q1.x * q2.x - q1.y * q2.y - q1.z * q2.z + q1.w * q2.w
    newQuat.x = q1.x * q2.w + q1.y * q2.z - q1.z * q2.y + q1.w * q2.x
    newQuat.y = -q1.x * q2.z + q1.y * q2.w + q1.z * q2.x + q1.w * q2.y
    newQuat.z = q1.x * q2.y - q1.y * q2.x + q1.z * q2.w + q1.w * q2.z
    return newQuat
end

local negaQ = function(q)
    return {
        w = q.w,
        x = -q.x,
        y = -q.y,
        z = -q.z
    }
end

local omega2Q = function (omega, tick)
    local omegaRot = {
        x = omega.x / tick,
        y = omega.y / tick,
        z = omega.z / tick
    }
    local sqrt = math.sqrt(omegaRot.x ^ 2 + omegaRot.y ^ 2 + omegaRot.z ^ 2)
    sqrt = math.abs(sqrt) > math.pi and copysign(math.pi, sqrt) or sqrt
    if sqrt ~= 0 then
        omegaRot.x = omegaRot.x / sqrt
        omegaRot.y = omegaRot.y / sqrt
        omegaRot.z = omegaRot.z / sqrt
        local halfTheta = sqrt / 2
        local sinHTheta = math.sin(halfTheta)
        return {
            w = math.cos(halfTheta),
            x = omegaRot.x * sinHTheta,
            y = omegaRot.y * sinHTheta,
            z = omegaRot.z * sinHTheta
        }
    else
        return nil
    end
end

local quatList = {
    west = {
        w = -1,
        x = 0,
        y = 0,
        z = 0
    },
    south = {
        w = -0.70710678118654752440084436210485,
        x = 0,
        y = -0.70710678118654752440084436210485,
        z = 0
    },
    east = {
        w = 0,
        x = 0,
        y = -1,
        z = 0
    },
    north = {
        w = -0.70710678118654752440084436210485,
        x = 0,
        y = 0.70710678118654752440084436210485,
        z = 0
    }
}

local getCannonPos = function()--校正中心点
    cannonAtt:getAtt()
    local wPos = cannonAtt.locate
    local offset = {
        x = properties.cannonOffset.x,
        y = properties.cannonOffset.y,
        z = properties.cannonOffset.z
    }
    offset = RotateVectorByQuat(cannonAtt.pose, offset)
    return {
        x = wPos.x - offset.x,
        y = wPos.y - offset.y,
        z = wPos.z - offset.z
    }
end

local getTime = function(dis, pitch) --获取炮弹飞行时间
    local barrelLength = #properties.barrelLength == 0 and 0 or tonumber(properties.barrelLength)
    barrelLength = barrelLength and barrelLength or 0
    local cosP = math.abs(math.cos(pitch))
    dis = dis - barrelLength * cosP

    local v0 = #properties.velocity == 0 and 0 or tonumber(properties.velocity) / 20
    v0 = v0 and v0 or 0

    local drag = #properties.drag == 0 and 0 or tonumber(properties.drag)
    drag = drag and 1 - drag or 0.99
    
    local result

    if drag < 0.001 or drag > 0.999 then
        result = dis / (cosP * v0)
    else
        result = math.abs(math.log(1 - dis / (100 * (cosP * v0))) / ln(drag))
    end
    -- local result = math.log((dis * lnD) / (v0 * cosP) + 1, drag)

    return result and result or 0
end

local getY2 = function(t, y0, pitch) --获取当前时间炮弹位置
    if t > 10000 then
        return 0
    end
    local grav = #properties.gravity == 0 and 0 or tonumber(properties.gravity)
    grav = grav and grav or 0.05
    local sinP = math.sin(pitch)
    local barrelLength = #properties.barrelLength == 0 and 0 or tonumber(properties.barrelLength)
    barrelLength = barrelLength and barrelLength or 0
    y0 = barrelLength * sinP + y0
    local v0 = #properties.velocity == 0 and 0 or tonumber(properties.velocity) / 20
    v0 = v0 and v0 or 0
    local Vy = v0 * sinP

    local drag = #properties.drag == 0 and 0 or tonumber(properties.drag)
    drag = drag and 1 - drag or 0.99
    if drag < 0.001 then
        drag = 1
    end
    local index = 1
    local last = 0
    while index < t + 1 do
        y0 = y0 + Vy
        Vy = drag * Vy - grav
        if index == math.floor(t) then
            last = y0
        end
        index = index + 1
    end
    
    return math.lerp(last, y0, t % math.floor(t))
end

local ag_binary_search = function(arr, xDis, y0, yDis) --二分
    local low = 1
    local high = #arr
    local mid, time
    local pitch, result = 0, 0
    while low <= high do
        mid = math.floor((low + high) / 2)
        pitch = arr[mid]
        time = getTime(xDis, pitch)
        result = yDis - getY2(time, y0, pitch)
        if result >= -0.018 and result <= 0.018 then
            break
            --return mid, time
        elseif result > 0 then
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return pitch, time
end

local pitchList = {} --角度表
for i = -90, 90, 0.0375 do
    table.insert(pitchList, math.rad(i))
end

--[[local targetVec = function (targetx, targety, targetz, x, y, z)--坐标差
    local targetvec = {
        x = targetx - x,
        y = targety - y,
        z = targetz - z
    }
    return targetvec
end--]]

local distance = function (tgVec) --距离计算
    local disx = math.sqrt(tgVec.x^2 + tgVec.z^2)
    local disy = tgVec.y
    return disx, disy
end

local pdCt = function(tgYaw, omega, p, d)
    local result = tgYaw * p + omega * d
    return math.abs(result) > properties.max_rotate_speed and copysign(properties.max_rotate_speed, result) or result
end

local controlCenter = {
    x = 0,
    y = 0,
    z = 0
}
local controltime = 0

local listener = function()
    local YawId, PitchId = getBearId()
    local controlCenterId = #properties.controlCenterId == 0 and 0 or tonumber(properties.controlCenterId)
    controlCenterId = controlCenterId and controlCenterId or 0
    while true do
        local id, msg = rednet.receive(protocol, 2)
        if not id then
            YawId, PitchId = getBearId()
        elseif id == YawId then
            parent.quat = msg.quat
            parent.omega = msg.omega
            parent.slug = msg.slug
            parent.velocity = msg.velocity
            parent.pos = msg.pos
        elseif id == PitchId then
            pitchParent.slug = msg.slug
        elseif id == controlCenterId then
            controlCenter = msg
            controltime = 20
        end
    end
end





local run = function ()
    while true do
        cannonAtt:getAtt()
        local controltime = 20
        local cannonlocat = getCannonPos()
        local omega = RotateVectorByQuat(negaQ(cannonAtt.pose), sublevel.getAngularVelocity())
        
        local nextQ, pNextQ = cannonAtt.pose, parent.quat

        local forecastRot = #properties.forecastRot == 0 and 0 or tonumber(properties.forecastRot)
        forecastRot = forecastRot and forecastRot or 16

        local omegaQuat = omega2Q(parent.omega, 20 / forecastRot)

        if omegaQuat then
            nextQ = quatMultiply(nextQ, omegaQuat)
            pNextQ = quatMultiply(pNextQ, omegaQuat)
        end
        local pErr = {
            x = cannonlocat.x - parent.pos.x,
            y = cannonlocat.y - parent.pos.y,
            z = cannonlocat.z - parent.pos.z,
        }
        local pErr1 = {
            x = cannonlocat.x - parent.pos.x,
            y = cannonlocat.y - parent.pos.y,
            z = cannonlocat.z - parent.pos.z,
        }

        local pNextQ2 = parent.quat
        local omegaQ2 = omega2Q(parent.omega, 6 / forecastRot)
        if omegaQ2 then--自身旋转补偿
            pNextQ2 = quatMultiply(pNextQ2, omegaQ2)
        end
        pErr = RotateVectorByQuat(negaQ(parent.quat), pErr)
        pErr = RotateVectorByQuat(pNextQ2, pErr)

        local forecastMov = #properties.forecastMov == 0 and 0 or tonumber(properties.forecastMov)
        forecastMov = forecastMov and forecastMov or 16
        local cannonPos = {--位移补偿
            x = cannonlocat.x + parent.velocity.x * forecastMov,
            y = cannonlocat.y + parent.velocity.y * forecastMov,
            z = cannonlocat.z + parent.velocity.z * forecastMov
        }
        print(pErr.x, pErr.y, pErr.z)

        cannonPos.x = cannonPos.x + pErr.x - pErr1.x
        cannonPos.y = cannonPos.y + pErr.y - pErr1.y
        cannonPos.z = cannonPos.z + pErr.z - pErr1.z
        

        local target ={
            
        }
        print(cannonlocat.x, cannonlocat.y, cannonlocat.z)
        print(cannonPos.x, cannonPos.y, cannonPos.z)
        print(parent.velocity.x, parent.velocity.y, parent.velocity.z)
   

        if controltime > 0 then
            controltime = controltime - 1
            controlCenter.y = controlCenter.y + 0.5
            local tgVec = {
                x = controlCenter.x - cannonPos.x,
                y = controlCenter.y - cannonPos.y,
                z = controlCenter.z - cannonPos.z
            }
            print(controlCenter.x, controlCenter.y, controlCenter.z)
            local xDis = math.sqrt(tgVec.x^2 + tgVec.z^2)
            local cannonPitch, time = ag_binary_search(pitchList, xDis, 0, tgVec.y)
            monitor.setCursorPos ( 1 , 1 )
            monitor.write("P"..cannonPitch)
            monitor.setCursorPos ( 1 , 2 )
            monitor.write("T"..time)
            


            local tmpVec
            local _c = math.sqrt(tgVec.x ^ 2 + tgVec.z ^ 2)
            local allDis = math.sqrt(tgVec.x ^ 2 + tgVec.y ^ 2 + tgVec.z ^ 2)
            local cosP = math.cos(cannonPitch)
            tmpVec = {--大炮朝向向量
                    x = allDis * (tgVec.x / _c) * cosP,
                    y = allDis * math.sin(cannonPitch),
                    z = allDis * (tgVec.z / _c) * cosP
                }
            local rot = RotateVectorByQuat(quatMultiply(quatList["north"], negaQ(nextQ)), tmpVec)--计算大炮角度

            local tmpYaw = -math.deg(math.atan2(rot.z, -rot.x))
            local tmpPitch = -math.deg(math.asin(rot.y / math.sqrt(rot.x ^ 2 + rot.y ^ 2 + rot.z ^ 2)))
        
            local localVec = RotateVectorByQuat(quatMultiply(quatList["north"], negaQ(parent.quat)), tmpVec)--带入底座方向计算角度

            local localYaw = -math.deg(math.atan2(localVec.z, -localVec.x))
            local localPitch = math.deg(math.asin(localVec.y / math.sqrt(localVec.x ^ 2 + localVec.y ^ 2 + localVec.z ^ 2)))
        
            local p, d = 5, 1
            local yawSpeed = math.floor(pdCt(tmpYaw, omega.y, p, d) + 0.5)
            local pitchSpeed = math.floor(pdCt(tmpPitch, -omega.z, p, d) + 0.5)


            local YawId, PitchId = getBearId()
            rednet.send(YawId, yawSpeed, protocol)
            rednet.send(PitchId, pitchSpeed, protocol)

            monitor.setCursorPos ( 1 , 3 )
            monitor.write("Y"..tmpYaw)
            monitor.setCursorPos ( 1 , 4 )
            monitor.write("X"..tmpPitch)
        end 



    end  
end



parallel.waitForAll(run, listener)
