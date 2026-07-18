local gear = peripheral.find("Create_RotationSpeedController")
local protocol = "CBCNetWork"
peripheral.find("modem", rednet.open)

local parentId = 1

local newVec = function() --坐标表格定义
    return {
        x = 0,
        y = 0,
        z = 0
    }
end

local newQuat = function ()
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

function cannonAtt:getAtt() --获取位置
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

local getConjQuat = function(q)
    return {
        w = q.w,
        x = -q.x,
        y = -q.y,
        z = -q.z
    }
end

gear.setTargetSpeed(0)
local id, msg
local run = function ()
    local slug = "1"
    while true do
        cannonAtt:getAtt()
        repeat
            id, msg = rednet.receive(protocol)
        until id == parentId
        if msg ~= msg then
            msg = 0
        end
        gear.setTargetSpeed(msg)
        print(msg)
        if parentId then
            local q = cannonAtt.pose
            local velocity = sublevel.getLinearVelocity()
            velocity.x = velocity.x / 20
            velocity.y = velocity.y / 20
            velocity.z = velocity.z / 20
            local sendMsg = {
                quat = q,
                slug = slug,
                omega = RotateVectorByQuat(getConjQuat(q), sublevel.getAngularVelocity()),
                velocity = velocity,
                pos = cannonAtt.locate
            }
            rednet.send(parentId, sendMsg, protocol)
        end
    end
end

parallel.waitForAll(run)