local _, addon = ...

-- Optional APIs/databases: no log selection changes and no guessed NPC names.
function addon.TurnInDetails(questID)
    local parts, columns = {}, { npc = {}, location = {} }
    local function call(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, result = pcall(fn, ...)
        return ok and result or nil
    end
    local log = C_QuestLog or {}
    local waypoint = call(log.GetNextWaypointText, questID)
    if type(waypoint) == "string" and waypoint ~= "" then parts[#parts+1] = waypoint; columns.location[#columns.location+1] = waypoint end
    local mapID = call(log.GetNextWaypoint, questID)
    local map = mapID and C_Map and call(C_Map.GetMapInfo, mapID)
    if type(map) == "table" and type(map.name) == "string" and map.name ~= "" then parts[#parts+1] = map.name; columns.location[#columns.location+1] = map.name end
    local loader = _G.QuestieLoader
    local db = loader and call(loader.ImportModule, loader, "QuestieDB")
    local provider = _G.LibQuestieDB
    local function query(kind, id, field)
        local entity = type(provider) == "table" and provider[kind]
        local value = type(entity) == "table" and call(entity.Get, id, field)
        if value ~= nil and value ~= false then return value end
        if type(db) == "table" then return call(kind == "Quest" and db.QueryQuestSingle or db.QueryNPCSingle, id, field) end
    end
    if type(provider) == "table" or type(db) == "table" then
        local finishers = query("Quest", questID, "finishedBy")
        local npcs = type(finishers) == "table" and finishers[1]
        if type(npcs) == "table" then
            local names = {}
            for _, id in ipairs(npcs) do
                local name = query("Npc", id, "name")
                if type(name) == "string" and name ~= "" then
                    local locations = {}
                    local spawns = query("Npc", id, "spawns")
                    if type(spawns) == "table" then
                        local areas = {}
                        for area in pairs(spawns) do if type(area) == "number" then areas[#areas+1] = area end end
                        table.sort(areas)
                        for _, area in ipairs(areas) do
                            local zone = call(C_Map and C_Map.GetAreaInfo or GetAreaInfo, area)
                            if type(zone) == "string" and zone ~= "" then
                                local point = type(spawns[area]) == "table" and spawns[area][1]
                                local x, y = type(point) == "table" and point[1], type(point) == "table" and point[2]
                                if type(x) == "number" and type(y) == "number" and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                                    zone = zone .. " (" .. addon.LocalizeDecimals(string.format("%.1f", x)) .. ", " .. addon.LocalizeDecimals(string.format("%.1f", y)) .. ")"
                                end
                                locations[#locations+1] = zone
                            end
                        end
                    end
                    names[#names+1] = name .. (#locations > 0 and (" — " .. table.concat(locations, " / ")) or "")
                    columns.npc[#columns.npc+1] = name
                    if #locations > 0 then columns.location[#columns.location+1] = table.concat(locations," / ") end
                end
            end
            if #names > 0 then parts[#parts+1] = table.concat(names, " / ") end
        end
    end
    return #parts > 0 and table.concat(parts, " · ") or nil,
        { npc = table.concat(columns.npc," / "), location = table.concat(columns.location," · ") }
end

function addon.NewSession(now, level, xp, maximum)
    return { started = now, level = level, xp = xp, maximum = maximum, gained = 0 }
end

function addon.Observe(session, level, xp, maximum)
    local gain
    if level == session.level then
        -- The XP reset can arrive before the level update. Wait for both values.
        if xp < session.xp then return end
        gain = xp - session.xp
    elseif level == session.level + 1 then
        gain = session.maximum - session.xp + xp
    else
        -- Unknown intermediate level requirements: start a fresh measurement.
        return false
    end
    session.gained = session.gained + math.max(0, gain)
    session.level, session.xp, session.maximum = level, xp, maximum
    return true
end

function addon.Rate(session, now)
    local elapsed = now - session.started
    if elapsed <= 0 then return 0 end
    return session.gained * 3600 / elapsed
end

function addon.Forecast(xp, maximum, ready, ongoing)
    if maximum <= 0 then return 0, 0, 0 end
    local current = math.min(1, math.max(0, xp / maximum))
    local completed = math.min(1 - current, math.max(0, ready / maximum))
    local pending = math.min(1 - current - completed, math.max(0, ongoing / maximum))
    return current, completed, pending
end
