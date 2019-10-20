--[[
    Applied Energetics 2 Item list write out
    Version: 1.0.0
    Author: GamerMan7799
    Purpose: A script that will write out all items in the network to a file. 
]]--

local component = require("component")
local fs = require("filesystem")

if component.me_controller ~= nil then 
    local list = component.me_controller.getItemsInNetwork()
    local file = assert(io.open("networklog.txt","w"))
    for k,v in ipairs(list) do
        file:write(k .. "     " .. v.name.. "     " .. v.label .. "     " .. v.size .. "\n")
    end 
    file:close()
else 
    print("Error getting ME controller, adapter not connected?")
end
    