--[[
    Applied Energetics 2 Storage Cleaner
    Version: 0.9.2
    Author: GamerMan7799
    Purpose: An automatic solution to keeping our AE system from getting clogged with too many useless items.
]]--
-- TODO figure out threads
-- TODO finish compress actions
--[[ Start Config values]]--
-- How long in seconds before doing another system clean
local sleepBetweenLoops = 60

-- Long (in ticks) to wait before refresh the config files to find updated items, set to -1 to disable
local configRefreshRate = 12000

-- Config file name for items
local itemConfigFile = "/etc/aecleaner-items.cfg"

-- Config file name for export buses
local busesConfigFile = "/etc/aecleaner-buses.cfg"

-- Where log file will be written to
local logFileLocation = "log-aecleaner.log"

-- If logging to file is enabled 
local logToFile = false

-- Level of verboseness of the logging, varies between 0-9, 0 is no logging, 9 is all the logging 
local logVerboseLevel = 5

-- If script will run in debug mode, with more messages
local debugMode = true
--[[ End Config values ]]--
--[[ Start Variable declaration ]]--
local component = require("component")
local fs = require("filesystem")
local sides = require("sides")
local text = require("text")
local table = require("table")
local string = require("string")
local thread = require("thread")
local event = require("event")
local serialization = require("serialization")
local keyboard = require("keyboard")
local exportVoid = {}
local exportStore = {}
local meControllerAddress = nil
local proxyController = nil
local proxyStore = nil
local proxyVoid = nil
local itemList = {}
local itemConf = {}
local limitCap = {}
local limitCompress = {}
local itemFilteredList = {}
local systemsEnabled = {}
local foundCap = {}
local foundCompress = {}
local foundDiscard = {}
local foundStore = {}
local lastRefreshTime = os.time()
local stopLoop = false
--[[ End Variable declaration ]]--
--[[ Start Function declaration ]]--
function handleLogging(message,level)
    if logVerboseLevel ~= 0 then 
        if level <= logVerboseLevel then 
            print(message)
            if logToFile then 
                local logfile = assert(io.open(logFileLocation,"a"))
                logfile:write(message .. "\n")
                logFile:close()
            end 
        end 
    end
end 
--
function start()
    systemsEnabled = {false,false,false}
    handleLogging("Script starting",1)
    processConfig()
    handleLogging("Items in config",8)
    handleLogging(serialization.serialize(itemConf),8)
    clearExportBus("void")
    clearExportBus("store")
    pollItemList()
end
--
function getSide(dir)
    if dir == "down" then return 0;
    elseif dir == "up" then return 1;
    elseif dir == "north" then return 2;
    elseif dir == "south" then return 3;
    elseif dir == "west" then return 4;
    elseif dir == "east" then return 5;
    else return -1;
    end
end
--
function processConfig()
    handleLogging("Processing item Config",8)
    -- Reads in the config file and enters data where it needs to go
    if fs.exists(itemConfigFile) then
        local file = assert(io.open(itemConfigFile,"r"))
        local endOfFile = false
        line = file:read("*line") -- Read in first line, and then discard data since it is just the header
        repeat
            line = file:read("*line")
            if line == nil then
                endOfFile = true
            else
                local new_item = text.tokenize(string.lower(line))
                if new_item[2] == "cap" or new_item[2] == "compress" or new_item[2] == "discard" or new_item[2] == "store"  then
                    -- new item has cap limit
                    handleLogging("Found ".. new_item[2] .." item of " .. new_item[1] .. " at cap of " .. new_item[3],8)
                    table.insert(itemConf,new_item)
                else
                    -- invalid action
                    handleLogging(new_item[1] .. " has invalid action of \"" .. new_item[2] .. "\" skipping",3)
                end
            end
        until endOfFile
        file:close()
        handleLogging("Item config processed",9)
    else
        handleLogging("Item config file not found, default config made at " .. itemConfigFile .. ", and script will exit",1)
        local file = assert(io.open(busesConfigFile,"w"))
        file:write("name action limit label_optional compress_name compress_label_optional\n")
        file:write("minecraft:dirt cap 50 dirt\n")
        file:close()
        os.exit()
    end
    handleLogging("Processing buses Config",8)
    if fs.exists(busesConfigFile) then
        local file = assert(io.open(busesConfigFile,"r"))
        local endOfFile = false
        line = file:read("*line") -- Read in first line, and then discard data since it is just the header
        repeat
            line = file:read("*line")
            if line == nil then
                endOfFile = true
            else
                local new_bus = text.tokenize(line)
                if new_bus[1] == "controller" then
                    meControllerAddress = new_bus[2];
                    handleLogging("Found controller address of " .. new_bus[2],8)
                    if component.type(meControllerAddress) == "me_controller" then
                        systemsEnabled[1] = true
                        proxyController = component.proxy(meControllerAddress)
                    else
                        handleLogging("Address " .. meControllerAddress .. " does not correspond to an me_controller.",1)
                        os.exit()
                    end
                elseif new_bus[1] == "void" then
                    exportVoid[1] = new_bus[2]
                    handleLogging("Found void export address of " .. exportVoid[1],8)
                    if component.type(exportVoid[1]) == "me_exportbus" then
                        handleLogging("Void address is a me_exportbus",9)
                        systemsEnabled[2] = true
                        proxyVoid = component.proxy(exportVoid[1])
                    else
                        handleLogging("Address " .. exportVoid[1] .. " does not correspond to a void me_exportbus.",2)
                        handleLogging("Void action has been disabled.",2)
                        systemsEnabled[2] = false
                    end
                    exportVoid[2] = getSide(new_bus[3])
                elseif new_bus[1] == "store" then
                    exportStore[1] = new_bus[2]
                    handleLogging("Found store export address of " ..  exportStore[1],8)
                    if component.type(exportStore[1]) == "me_exportbus" then
                        handleLogging("Store address is a me_exportbus",9)
                        proxyStore = component.proxy(exportStore[1])
                        systemsEnabled[3] = true
                    else
                        handleLogging("Address " .. exportStore[1] .. " does not correspond to a store me_exportbus.",2)
                        handleLogging("Store action has been disabled.",2)
                        systemsEnabled[3] = false
                    end
                    exportStore[2] = getSide(new_bus[3])
                else
                    handleLogging("Unknown bus type found",2)
                end
            end
        until endOfFile
        file:close()
        -- Test each of the addresses to double check they are correct
        component.setPrimary("me_controller",meControllerAddress)
        if component.database == nil then
            handleLogging("No database found, add upgrade to adapter, script exiting",1)
            os.exit()
        end
        if systemsEnabled[2] and proxyVoid == nil then
            handleLogging("Void export address is invalid, script will continue but action will be disabled",2)
            systemsEnabled[2] = false
        end
        if systemsEnabled[3] and proxyStore == nil then
            handleLogging("Store export address is invalid, script will continue but action will be disabled",2)
            systemsEnabled[3] = false
        end
    else
        handleLogging("Bus config file not found, default config made at " .. busesConfigFile .. ", and script will exit",1)
        local file = assert(io.open(busesConfigFile,"w"))
        file:write("Type Address dir-facing\n")
        file:write("controller XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX none\n")
        file:write("void XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX down\n")
        file:write("store XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX south\n")
        file:close()
        os.exit()
    end
end
--
function clearExportBus(bus_name)
    -- Clear the export bus from exporting anything
    component.database.clear(1) -- clear database
    if bus_name == "void" and systemsEnabled[2] then
        proxyVoid.setExportConfiguration(exportVoid[2])
    elseif bus_name == "store" and systemsEnabled[3] then
        proxyStore.setExportConfiguration(exportStore[2])
    else
        handleLogging("Invalid bus name of " .. bus_name .. " this shouldn't happen. Report to script maker",1)
    end
end
--
function setExportBus(bus_name)
    -- Sets item to be exported
    if bus_name == "void" and systemsEnabled[2] then
        proxyVoid.setExportConfiguration(exportVoid[2],component.database.address,1)
    elseif bus_name == "store" and systemsEnabled[3] then
        proxyStore.setExportConfiguration(exportStore[2],component.database.address,1)
    else
        handleLogging("Invalid bus name of " .. bus_name .. " this shouldn't happen. Report to script maker",1)
    end
end
--
function pollItemList()
    if systemsEnabled[1] then
        itemList = proxyController.getItemsInNetwork()
    else
        handleLogging("No connection to meController, cannot poll items. Script stopping.",1)
        os.exit()
    end
end
--
function compareItems(mesys,confitem)
    -- Compares an item from the config list to one in the me system, returns if
    -- they are same item or not

    -- check item name
    if mesys ~= nil and confitem ~= nil then
        if string.lower(mesys.name) == string.lower(confitem[1]) then
            -- next check if optional label is also part of item
            if confitem[4] ~= "" and confitem[4] ~= " " and confitem[4] ~= nil and confitem[4] ~= "\n" then
                local melabel = string.lower(mesys.label)
                local conflabel = string.lower(confitem[4])
                if string.match(melabel,conflabel) then
                    return true
                else
                    return false
                end
            else
                return true
            end
        else
            return false
        end
    else
        handleLogging("Found nil item name",9)
    end
end
--
function checkCap(mesys,limit)
    -- Checks if item is past cap and then handles the loop to dump until
    -- below limit
    if mesys.size > tonumber(limit) then
        handleLogging("Cap Item: " .. mesys.name .. " x" .. mesys.size .. " exceeds limit of " .. limit,5)
        doDiscard(mesys,limit)
    else
        handleLogging("Cap Item: " .. mesys.name .. " x" .. mesys.size .. " not at limit of " .. limit,6)
    end
end
--
function checkCompress(mesys,limit)
    -- Checks if item is past compress cap and then handles the loop to compress until
    -- below limit
    if mesys.size > tonumber(limit) then
        handleLogging("Compress Item: " .. mesys.name .. " x" .. mesys.size .. " exceeds limit of " .. limit,5)
        handleLogging("Compress currently WIP, does nothing.",5)
    else
        handleLogging("Compress Item: " .. mesys.name .. " x" .. mesys.size .. " not at limit of " .. limit,6)
    end
end
--
function doDiscard(mesys,desired_amount)
    -- dumps item until at or below desired amount
    if systemsEnabled[2] then
        proxyController.store(mesys,component.database.address,1,1)
        setExportBus("void")
        local dumpAmount = mesys.size - desired_amount
        local amountDumped = 0
        handleLogging("System is discarding " .. dumpAmount .. " of " .. mesys.name .. "-" .. mesys.label,3)
        while (dumpAmount > 0) do
            amountDumped = proxyVoid.exportIntoSlot(exportVoid[2])
            if amountDumped == nil then 
                handleLogging("Error discarding " .. mesys.name .. "-" .. mesys.label,2)
                dumpAmount = -1
            else
                dumpAmount = dumpAmount - amountDumped
            end
        end
        clearExportBus("void")
    else
        handleLogging("Void export bus not enabled, skipping discard",7)
    end
end
--
function doStore(mesys)
    -- stores desired item
    if systemsEnabled[3] then
        proxyController.store(mesys,component.database.address,1,1)
        setExportBus("store")
        local dumpAmount = mesys.size
        local amountDumped = 0
        handleLogging("System is storing " .. dumpAmount .. " of " .. mesys.name .. "-" .. mesys.label,3)
        while (dumpAmount > 0) do
            amountDumped = proxyStore.exportIntoSlot(exportStore[2])
            if amountDumped == nil then 
                handleLogging("Error storing " .. mesys.name .. "-" .. mesys.label .. ", storage might be full",1)
                dumpAmount = -1
            else
                dumpAmount = dumpAmount - amountDumped
            end
        end
        clearExportBus("store")
    else
        handleLogging("Store export bus not enabled, skipping store",7)
    end
end
--
function identifyItems()
    -- Loops through the ME item list pool and places found items in corresponding tables to be tracked later on
    -- clear tables, so there are no leftover items
    foundCap = {}
    foundCompress = {}
    foundDiscard = {}
    foundStore = {}
    limitCap = {}
    limitCompress = {}
    for i, item in ipairs(itemList) do -- for each item in ME system
        for j = 1, #itemConf do -- for each item configured
            if compareItems(item,itemConf[j]) then
                if itemConf[j][2] == "cap" then
                    handleLogging("Found item ".. item.name .. " to be capped at " .. itemConf[j][3],7)
                    table.insert(foundCap,item)
                    table.insert(limitCap,itemConf[j][3])
                elseif itemConf[j][2] == "compress" then
                    handleLogging("Found item ".. item.name .. " to be compressed at " .. itemConf[j][3],7)
                    table.insert(foundCompress,item)
                    table.insert(limitCompress,itemConf[j][3])
                elseif itemConf[j][2] == "discard" then
                    handleLogging("Found item ".. item.name .. " to be discarded",7)
                    table.insert(foundDiscard,item)
                elseif itemConf[j][2] == "store" then
                    handleLogging("Found item ".. item.name .. " to be stored",7)
                    table.insert(foundStore,item)
                end
            end
        end
    end
end
--
function doRefresh()
    lastRefreshTime = os.time()
    handleLogging("Script is refreshing all configs",3)
    -- clear all global values
    clearExportBus("void")
    clearExportBus("store")
    exportVoid = {}
    exportStore = {}
    proxyController = nil 
    proxyStore = nil 
    proxyVoid = nil
    limitCap = {}
    start()
end
--
function checkExit()
    while not stopLoop do 
        local e,_,_,key = event.pull("key_down")
        if keyboard.isControlDown()then
            stopLoop = true 
        end
    end
end
--[[ End Function declaration ]]--
--[[ Start Main script ]]--
thread.create(function()
  checkExit()
end)

thread.create(function()
  start()
  repeat
        pollItemList()
        identifyItems()
        for i, item in ipairs(foundDiscard) do doDiscard(item,0) end
        for i, item in ipairs(foundStore) do doStore(item) end
        for i, item in ipairs(foundCap) do checkCap(item,limitCap[i]) end
        for i, item in ipairs(foundCompress) do checkCompress(item,limitCompress[i]) end
        --checkExit()
        if (os.time() - lastRefreshTime >= configRefreshRate) and not stopLoop then
            doRefresh()
        end
        handleLogging("Cycle complete, sleeping for " .. sleepBetweenLoops .. "seconds before next cycle.",7)
        os.sleep(sleepBetweenLoops)
    until stopLoop
end)
--[[ End Main script ]]--
