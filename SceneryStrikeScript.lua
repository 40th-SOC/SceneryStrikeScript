scenery = {}

do

    local internalConfig = {}

    local configDefaults = {
        ["POLL_INTERVAL"] = 600,
        ["WRITE_REPORT"] = true,
        ["REPORT_FILENAME"] = "scenery_strike_report.csv",
        ["ZONES"] = {},
    }

    -- Table of buliding IDs and their corresponding zone
    -- { [123345] = "zone 1"}
    local buildingLookup = {}

    -- {
    --  ["zone1"] = "dead",
    --  ["zone2"] = "alive",
    -- }
    local zoneStatus = {}

    local function log(tmpl, ...)
        local txt = string.format("[SCENE] " .. tmpl, ...)

        if __DEV_ENV == true then
            trigger.action.outText(txt, 30) 
        end

        env.info(txt)
    end

    local function buildConfig()
        local cfg = mist.utils.deepCopy(configDefaults)
        
        if scenery.config then
            for k,v in pairs(scenery.config) do
                cfg[k] = v
            end
        end

        return cfg
    end

    local function getReportFile()
        local fileName = string.format("%s\\%s", lfs.writedir(), internalConfig.REPORT_FILENAME)
        local fp = io.open(fileName, 'w')

        return fp
    end

    local function writeReport()
        local fp = getReportFile()

        if not fp then
            log("Could not get file handle")
            return
        end

        local csv = ""
        for zone,status in pairs(zoneStatus) do
            local row = string.format("%s,%s\n", zone, status)
            csv = csv .. row
        end

        log("Writing report file...")
        fp:write(csv)
        fp:close()
    end

    local function findSceneryObjects(zone)
        local foundObjects = {}
        local z = trigger.misc.getZone(zone)

        if not z then
            log("zone %s not found", zone)
            return
        end
    
        local cb = function(item, val)
            table.insert(foundObjects, item)
        end
    
        
        world.searchObjects(Object.Category.SCENERY, {
            id = world.VolumeType.SPHERE,
            params = {
              point = z.point,
              radius = z.radius,
            },
        }, cb)
    
        return foundObjects
    end

    local function setup()
        for zone,targetCount in pairs(internalConfig.ZONES) do

            zoneStatus[zone] = "alive"

            local objs = findSceneryObjects(zone)

            if not objs then
                log("no objects found in zone %s. Aborting...", zone)
                return
            end
            
            for i,o in ipairs(objs) do
                buildingLookup[o:getName()] = zone
            end
        end
    end

    local function eventHandler(event)
        local object = event.initiator
        if object == nil then
            return
        end

        if event.id == world.event.S_EVENT_DEAD and object:getCategory() == Object.Category.SCENERY then
            local zone = buildingLookup[object:getName()]

            if zone then
                local deadObjects = mist.getDeadMapObjsInZones({ zone })

                if #deadObjects >= internalConfig.ZONES[zone] then
                    log("%s target(s) destroyed", zone)

                    zoneStatus[zone] = "dead"
                    writeReport()
                end
            end
        end
    end

    function scenery.init()
        internalConfig = buildConfig()
        log(mist.utils.tableShow(internalConfig))

        setup()
        writeReport()
        mist.addEventHandler(eventHandler)

        trigger.action.outText("SceneryStrikeScript initialized", 30)
    end
end