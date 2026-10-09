local addon = {}
assert(loadfile("Model.lua"))("TillNextLevel",addon)
assert(addon.TurnInDetails(10) == nil)
C_QuestLog = { GetNextWaypointText = function(id) assert(id==10); return "Speak to the captain" end,
    GetNextWaypoint = function() return 100, .5, .5 end }
C_Map = { GetMapInfo = function(id) assert(id==100); return {name="Stormwind"} end }
assert(addon.TurnInDetails(10) == "Speak to the captain · Stormwind")
QuestieLoader = { ImportModule = function(_,module)
    assert(module=="QuestieDB")
    return { QueryQuestSingle = function(id,key) assert(id==10 and key=="finishedBy"); return {{42,43},{}} end,
        QueryNPCSingle = function(id,key) assert(key=="name"); return id==42 and "Captain" or "Lieutenant" end }
end }
assert(addon.TurnInDetails(10) == "Speak to the captain · Stormwind · Captain / Lieutenant")
C_QuestLog.GetNextWaypointText = function() error("Unavailable") end
C_QuestLog.GetNextWaypoint = function() error("Unavailable") end
QuestieLoader.ImportModule = function() error("Not initialized") end
assert(addon.TurnInDetails(10) == nil)
QuestieLoader.ImportModule = function() return {QueryQuestSingle=function() return { {}, {99} } end} end
assert(addon.TurnInDetails(10) == nil, "Object finisher is not labeled as an NPC")
print("turn-in details: OK")
QuestieLoader = nil
LibQuestieDB = {
    Quest = { Get = function(id,key) assert(id==10 and key=="finishedBy"); return {{42},{}} end },
    Npc = { Get = function(id,key)
        assert(id==42)
        if key=="name" then return "Captain" end
        if key=="spawns" then return { [1519] = {{45.24,61.76}} } end
    end },
}
C_Map.GetAreaInfo = function(id) assert(id==1519); return "Stormwind" end
addon.LocalizeDecimals = function(text) return text end
assert(addon.TurnInDetails(10) == "Captain — Stormwind (45.2, 61.8)", "Standalone QuestieDB works without QuestieLoader")
LibQuestieDB.Quest.Get = function() return {{},{99}} end
assert(addon.TurnInDetails(10) == nil, "Standalone object finisher does not invent NPC")
LibQuestieDB.Quest.Get = function() error("Not ready") end
assert(addon.TurnInDetails(10) == nil)
print("standalone QuestieDB: OK")
