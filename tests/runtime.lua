local addon, frames, clock = {}, {}, 0
local xp, maximum, level = 800, 1000, 10
local Methods = {}
function Methods:SetScript(name, callback) self.scripts[name] = callback end
function Methods:RegisterEvent(event) self.events[event] = true end
function Methods:SetText(value) self.text = value end
function Methods:ClearLines() self.lines = {} end
function Methods:AddDoubleLine(...) self.lines = self.lines or {}; self.lines[#self.lines+1] = {...} end
function Methods:GetWidth() return 436 end
function Methods:GetCenter() return 500, 500 end
function Methods:GetEffectiveScale() return 1 end
function Methods:SetShown(value) self.shown = value end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:SetSize(width,height) self.width,self.height=width,height end
function Methods:SetWidth(width) self.width=width end
function Methods:GetStringWidth() return #(self.text or "") * 7 end
function Methods:SetPoint(...) self.point={...} end
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
    { title = "Pending", questID = 20 },
    { title = "Ready", questID = 10 },
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
assert(frame.completed.text:find("|cff4dd9801",1,true))
assert(frame.pending.text:find("|cffffd1002",1,true))
frame.scripts.OnEnter()
local foundReady, foundPending, questOrder = false, false, {}
for _, row in ipairs(GameTooltip.lines) do
    if row[1] == "Ready" or row[1] == "Pending" or row[1] == "Unknown" then questOrder[#questOrder+1]=row[1] end
    if row[1] == "Ready" then assert(row[3]==.3 and row[4]==.85 and row[5]==.5 and row[6]==.3 and row[7]==.85 and row[8]==.5); foundReady=true end
    if row[1] == "Pending" then assert(row[3]==1 and row[4]==.82 and row[5]==0 and row[6]==1 and row[7]==.82 and row[8]==0); foundPending=true end
end
assert(foundReady and foundPending)
assert(table.concat(questOrder,",") == "Ready,Pending,Unknown", "Ready quests precede ongoing quests and preserve group order")
local originalTurnIn = addon.TurnInDetails
addon.TurnInDetails = function() return "Captain — Stormwind (45.2, 61.8)" end
frame.scripts.OnEnter()
local combined = false
for _, row in ipairs(GameTooltip.lines) do
    if row[1] == "Ready — Captain — Stormwind (45.2, 61.8)" then
        assert(row[2] == "150 " .. addon.L.xp and row[3] == .3 and row[4] == .85)
        combined = true
    end
end
assert(combined, "Quest and turn-in details share the reward row")
function GameTooltip:NumLines() return #self.lines end
for i=1,30 do _G["GameTooltipTextLeft"..i]=widget() end
addon.TurnInDetails = function() return "Captain — Stormwind", {npc="Captain",location="Stormwind"} end
frame.scripts.OnEnter()
local cells=frame.questTooltipColumns[1]
assert(cells[1].text=="Ready" and cells[2].text=="Captain" and cells[3].text=="Stormwind")
assert(frame.questTooltipColumns[2][2].text=="" and frame.questTooltipColumns[2][3].text=="", "Ongoing quests leave turn-in columns blank")
assert(cells[2].point[4]==frame.questTooltipColumns[2][2].point[4], "NPC column uses the same offset for every row")
assert(cells[3].point[4]==frame.questTooltipColumns[2][3].point[4], "Location column is aligned")
function GameTooltip:NumLines() return nil end
for i=1,30 do _G["GameTooltipTextLeft"..i]=nil end
addon.TurnInDetails = originalTurnIn
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
assert(TillNextLevelDB.skin == "modern" and frame.width == 520)
SlashCmdList.TILLNEXTLEVEL("skin classic")
assert(TillNextLevelDB.skin == "classic" and frame.width == 1000 and frame.height == 102)
assert(frame.title.shown and frame.stats.shown and not frame.progress.shown)
assert(frame.title.text:find("50",1,true) and frame.stats.text)
SlashCmdList.TILLNEXTLEVEL("skin invalid")
assert(TillNextLevelDB.skin == "classic")
fire("ADDON_LOADED","TillNextLevel")
assert(TillNextLevelDB.skin == "classic", "Saved skin survives initialization")
SlashCmdList.TILLNEXTLEVEL("options")
assert(TillNextLevelSkinOptions.shown)
TillNextLevelSkinOptions.modern.scripts.OnClick()
assert(not TillNextLevelSkinOptions.shown, "Selecting modern closes the chooser")
assert(TillNextLevelDB.skin == "modern" and frame.width == 520 and frame.progress.shown and not frame.title.shown)
frame.scripts.OnMouseUp(frame,"RightButton")
assert(TillNextLevelSkinOptions.shown)
TillNextLevelSkinOptions.classic.scripts.OnClick()
assert(not TillNextLevelSkinOptions.shown, "Selecting classic closes the chooser")
assert(TillNextLevelDB.skin == "classic")
xp, maximum = 28246, 31700
fire("PLAYER_XP_UPDATE", "player")
assert(frame.title.text:find("89" .. addon.decimalSeparator .. "10%",1,true))
assert(frame.title.text:find("10" .. addon.decimalSeparator .. "90%",1,true))
assert(not frame.title.text:find("104100",1,true))
level, maximum = 60, 0
fire("PLAYER_XP_UPDATE", "player")
assert(frame.level.text == string.format(addon.L.capped, 60))
assert(not frame.actual.shown)
assert(frame.title.text == string.format(addon.L.capped,60))
SlashCmdList.TILLNEXTLEVEL("skin modern")
print("runtime " .. GetLocale() .. ": OK")
