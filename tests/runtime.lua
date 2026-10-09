local addon, frames, clock = {}, {}, 0
local xp, maximum, level = 800, 1000, 10
local Methods = {}
function Methods:SetScript(name, callback) self.scripts[name] = callback end
function Methods:RegisterEvent(event) self.events[event] = true end
function Methods:SetText(value) self.text = value end
function Methods:GetWidth() return 436 end
function Methods:GetCenter() return 500, 500 end
function Methods:GetEffectiveScale() return 1 end
function Methods:SetShown(value) self.shown = value end
function Methods:IsOwned() return false end
function Methods:GetAlpha() return self.alpha or 1 end
function Methods:SetAlpha(value) self.alpha = value end
local function widget()
    return setmetatable({ scripts = {}, events = {} }, { __index = function(_, key)
        return Methods[key] or function() end
    end })
end
function Methods:CreateTexture() return widget() end
function Methods:CreateFontString() return widget() end
function CreateFrame(_, name)
    local object = widget()
    frames[#frames + 1] = object
    if name then _G[name] = object end
    return object
end
UIParent, GameTooltip = widget(), widget()
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
function GetLocale() return arg[1] or "frFR" end
function GetTime() return clock end
function UnitXP() return xp end
function UnitXPMax() return maximum end
function UnitLevel() return level end
function GetMaxPlayerLevel() return 60 end
function GetXPExhaustion() return 200 end
local log = {
    { title = "Zone", isHeader = true },
    { title = "Ready", questID = 10 },
    { title = "Pending", questID = 20 },
    { title = "Unknown", questID = 30 },
    { title = "Failed", questID = 40 },
    { title = "Hidden", questID = 50, isHidden = true },
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(index) return log[index] end,
    IsComplete = function(id) return id == 10 end,
    IsFailed = function(id) return id == 40 end,
}
function GetQuestLogRewardXP(id)
    if id == 10 then return 150 elseif id == 20 then return 300 end
end
assert(loadfile("Localization.lua"))("TillNextLevel", addon)
assert(loadfile("Model.lua"))("TillNextLevel", addon)
assert(loadfile("TillNextLevel.lua"))("TillNextLevel", addon)
local events = frames[1]
local function fire(event, ...) events.scripts.OnEvent(events, event, ...) end
fire("ADDON_LOADED", "TillNextLevel")
fire("PLAYER_LOGIN")
local frame = TillNextLevelFrame
MainMenuExpBar = widget()
MainMenuExpBar:SetAlpha(0.8)
SlashCmdList.TILLNEXTLEVEL("blizzard hide")
assert(TillNextLevelDB.hideBlizzardXP and MainMenuExpBar:GetAlpha() == 0)
MainMenuExpBar:SetAlpha(1)
events.scripts.OnUpdate(events, 1)
assert(MainMenuExpBar:GetAlpha() == 0)
SlashCmdList.TILLNEXTLEVEL("blizzard show")
assert(not TillNextLevelDB.hideBlizzardXP and MainMenuExpBar:GetAlpha() == 0.8)
local anonymousXP, reputation = widget(), widget()
anonymousXP:SetAlpha(1)
reputation:SetAlpha(1)
function anonymousXP:GetType() return "EXPERIENCE" end
function reputation:GetType() return "REPUTATION" end
StatusTrackingBarManager = { bars = { anonymousXP, reputation } }
SlashCmdList.TILLNEXTLEVEL("blizzard hide")
assert(anonymousXP:GetAlpha() == 0 and reputation:GetAlpha() == 1)
SlashCmdList.TILLNEXTLEVEL("blizzard show")
assert(anonymousXP:GetAlpha() == 1)
StatusTrackingBarManager = nil
StatusTrackingBarInfo = { BarsEnum = { Experience = 4, Reputation = 1 } }
local indexedXP, indexedRep, border = widget(), widget(), widget()
indexedXP:SetAlpha(1); indexedRep:SetAlpha(1); border:SetAlpha(0.7)
MainStatusTrackingBarContainer = widget()
MainStatusTrackingBarContainer:SetAlpha(1)
MainStatusTrackingBarContainer.bars = { [4] = indexedXP, [1] = indexedRep }
MainStatusTrackingBarContainer.shownBarIndex = 4
MainStatusTrackingBarContainer.MainMenuBarTextures = { border }
SlashCmdList.TILLNEXTLEVEL("blizzard hide")
assert(indexedXP:GetAlpha() == 0 and indexedRep:GetAlpha() == 1 and border:GetAlpha() == 0)
assert(MainStatusTrackingBarContainer:GetAlpha() == 0)
MainStatusTrackingBarContainer.shownBarIndex = 1
events.scripts.OnUpdate(events, 1)
assert(border:GetAlpha() == 0.7 and indexedRep:GetAlpha() == 1)
assert(MainStatusTrackingBarContainer:GetAlpha() == 1)
SlashCmdList.TILLNEXTLEVEL("blizzard show")
assert(indexedXP:GetAlpha() == 1)
MainStatusTrackingBarContainer, StatusTrackingBarInfo = nil, nil
assert(frame.progress.text:find("800 / 1" .. addon.thousandsSeparator .. "000", 1, true))
assert(frame.percent.text:find("80" .. addon.decimalSeparator .. "0%", 1, true))
assert(frame.completed.text:find("150", 1, true))
assert(frame.ongoing.shown)
assert(frame.pending.text:find("300", 1, true))
assert(frame.completed.text:find("(?)", 1, true))
clock, xp = 60, 900
fire("PLAYER_XP_UPDATE", "player")
assert(frame.rate.text:find("6" .. addon.thousandsSeparator .. "000", 1, true))
level, xp, maximum = 11, 50, 1200
fire("PLAYER_LEVEL_UP", 11)
assert(frame.rate.text:find("15" .. addon.thousandsSeparator .. "000", 1, true))
SlashCmdList.TILLNEXTLEVEL("reset")
assert(frame.rate.text == addon.L.rate .. ": 0")
SlashCmdList.TILLNEXTLEVEL("hide"); assert(not frame.shown)
SlashCmdList.TILLNEXTLEVEL("show"); assert(frame.shown)
SlashCmdList.TILLNEXTLEVEL("scale 9"); assert(TillNextLevelDB.scale == 1)
SlashCmdList.TILLNEXTLEVEL("scale 1.2"); assert(TillNextLevelDB.scale == 1.2)
SlashCmdList.TILLNEXTLEVEL("scale 1,3"); assert(TillNextLevelDB.scale == 1.3)
-- Client without reward API must still load and label the total as partial.
GetQuestLogRewardXP = nil
fire("QUEST_LOG_UPDATE")
events.scripts.OnUpdate(events, 1)
assert(frame.completed.text:find("0", 1, true) and frame.completed.text:find("(?)", 1, true))
frame.scripts.OnEnter()
level, maximum = 60, 0
fire("PLAYER_XP_UPDATE", "player")
assert(frame.level.text == string.format(addon.L.capped, 60))
assert(not frame.actual.shown)
print("runtime " .. GetLocale() .. ": OK")
