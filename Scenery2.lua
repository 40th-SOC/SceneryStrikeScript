scenery = {}

do
    local configDefaults = {
        ["RENDER_MENUS"] = true,
        ["RENDER_MARKPOINTS"] = true,
        ["MISSION_INDICATOR_ALPHA"] = 38,
        ["TARGET_INDICATOR_ALPHA"] = 255,
        ["STRIKE_ZONE_RGB"] = {r = 255, g = 0, b = 255},
        ["WRITE_REPORT"] = true,
        ["REPORT_FILENAME"] = "scenery_strike_report.csv",
        ["PERSISTENT"] = true,
    }

    local columns = {
        "targetZoneName",
        "dead",
    }
    
    -- [<scenery object id] = <tgt zone name>
    local buildingLookup = {}
    -- [<tgt zone name>] = <mission zone name>
    local targetToMissionLookup = {}
    -- [<tgt zone name>] = <destroyed bool>
    local destroyedBuildings = {}
    -- 
    local internalConfig = {}

    local eventHandlers = {}
    

    local function log(tmpl, ...)
        local txt = string.format("[SCENE] " .. tmpl, ...)

        if __DEV_ENV == true then
            trigger.action.outText(txt, 30) 
        end

        env.info(txt)
    end

    local function debugTable(tbl)
        log(mist.utils.tableShow(tbl))
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

    local function makeRecord(zoneName, destroyed)
        local record = {}
        for i,col in ipairs(columns) do
            record[col] = nil
        end

        record.targetZoneName = zoneName
        record.destroyed = destroyed
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
        for tgtZoneName,destroyed in pairs(destroyedBuildings) do
            local row = string.format("%s,%s\n", tgtZoneName, destroyed and "true" or "false")
            csv = csv .. row
        end

        log("Writing report file...")
        fp:write(csv)
        fp:close()
    end

    local function eventHandler(event)
        local object = event.initiator
        if object == nil then
            return
        end

        if event.id == world.event.S_EVENT_DEAD and object:getCategory() == Object.Category.SCENERY then
            local zone = buildingLookup[string.format("%s", object:getName())]

            if zone then
                log("Zone %s", zone)
                destroyedBuildings[zone] = true
                writeReport()
                for i,handler in ipairs(eventHandlers) do
                    handler(zone)
                end
            end
        end
    end

    local function round(number, decimals)
        local power = 10^decimals
        return math.floor(number * power) / power
    end

    local function rgbMatch(target, source)
        return target.r == source.r and target.g == source.g and target.b == source.b
    end

    local function findZones()
        local missionZones = {}
        local targetZones = {}

        for i,zone in ipairs(env.mission.triggers.zones) do
            -- Values are stored as decimals of 255
            local rgba = {
                r = round(zone.color[1] * 255, 3),
                g = round(zone.color[2] * 255, 3),
                b = round(zone.color[3] * 255, 3), 
                a = round(zone.color[4] * 255, 3),
            }

            if rgbMatch(internalConfig.STRIKE_ZONE_RGB, rgba) then
                if internalConfig.TARGET_INDICATOR_ALPHA == rgba.a then
                    targetZones[zone.name] = zone
                else if internalConfig.MISSION_INDICATOR_ALPHA == rgba.a then
                    missionZones[zone.name] = zone
                end
                end
            end
        end

        return missionZones, targetZones
    end

    local function printMissionInfo(params) 
        local lat, long = coord.LOtoLL(params.zone)
        local mgrs = coord.LLtoMGRS(lat, long)
        
        local str = string.format("Strike Mission: %s\n", params.name)
        str = str .. "--------------------------------------------------------\n"
        str = str .. string.format("L/L Seconds: %s\n", mist.tostringLL(lat, long, 2, true))
        str = str .. string.format("L/L Decimal: %s\n", mist.tostringLL(lat, long, 3)) 
        str = str .. string.format("MGRS: %s\n\n", mist.tostringMGRS(mgrs, 5))
        str = str .. "Check the map for individual target aim points"

        trigger.action.outTextForGroup(params.groupID, str, 90)
    end

    local function getReportFile(writeAccess)
        local fileName = string.format("%s\\%s", lfs.writedir(), internalConfig.REPORT_FILENAME)
        local file = io.open(fileName, writeAccess and 'w' or 'r')

        return file
    end

    local function readState(text)
        local pattern = ""
        local state = {}
        for i,col in ipairs(columns) do
            local s = i == #columns and "(.*)" or "(.*),"
            pattern = pattern .. s
        end

        for row in text:gmatch("[^\r\n]+") do
            local match = {string.match(row, pattern)}
            local record = {}

            for i,col in ipairs(columns) do
                record[col] = match[i]
            end

            table.insert(state, record)
        end

        return state
    end

    local function generateBuildingLookup(targetZones, missionZones)
        local markId = 1
        for name,tz in pairs(targetZones) do

            if tz then
                -- tz will be nil if the target is already dead
                for i,prop in ipairs(tz.properties) do
                    if prop.key == "OBJECT ID" then
                        buildingLookup[prop.value] = name
                    end
                end
            end


            for name,mz in pairs(missionZones) do
                if mist.pointInPolygon(tz, mz.verticies) then
                    targetToMissionLookup[tz.name] = mz.name
                end
            end

            if internalConfig.RENDER_MARKPOINTS then
                trigger.action.markToAll(markId, tz.name, { x = tz.x, z = tz.y }, true)
                markId = markId + 1
            end
        end
    end

    function scenery.init()
        internalConfig = buildConfig()
        local missionZones, targetZones = findZones()
        local fp = getReportFile()

        if fp then
            local text = fp:read("*all")
            fp:close()
    
            if text == "" then
                log("Error: could not read report file")
            else
                local state = readState(text)
                for i,row in ipairs(state) do
                    if targetZones[row.targetZoneName] and row.dead then
                        log("Target zone %s dead, removing...", row.targetZoneName)
                        targetZones[row.targetZoneName] = nil
                    end
                end
            end
        else
            log("Report file %s not found. Generating...", internalConfig.REPORT_FILENAME)
            writeReport()
        end

        generateBuildingLookup(targetZones, missionZones)

        if internalConfig.RENDER_MENUS then
            local m = {}
            for name, zone in pairs(missionZones) do
                local title = name:gsub("%b[]", "")
                table.insert(m, { title = title, func = printMissionInfo, params = { name = title, zone = zone } } )
            end

            menus.menuForAllGroups("Strike Missions", m)
        end

        mist.addEventHandler(eventHandler)
        trigger.action.outText("Scenery2 initialized", 30)
    end
end

scenery.init()