local addonName, addon = ...
local frame, session, db
local quests = { ready = 0, ongoing = 0, unknown = 0, rows = {} }
local questDirty, questElapsed, elapsed = true, 0, 0
local WHITE = "Interface\\Buttons\\WHITE8X8"
local fr = GetLocale() == "frFR"
local function T(french, english) return fr and french or english end
local function number(value)
    local s = tostring(math.floor(value + 0.5))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return formatted
end
local function duration(seconds)
    if not seconds or seconds == math.huge then return "--" end
    local minutes = math.ceil(seconds / 60)
    if minutes < 60 then return minutes .. " min" end
    return string.format("%dh %02d", math.floor(minutes / 60), minutes % 60)
end
local function message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff59cfffTill Next Level|r : " .. text)
end

local function ScanQuests()
    local log = C_QuestLog or {}
    local count = log.GetNumQuestLogEntries or GetNumQuestLogEntries
    quests = { ready = 0, ongoing = 0, unknown = 0, rows = {} }
    if not count then return end
    for index = 1, count() do
        local info
        if log.GetInfo then
            info = log.GetInfo(index)
        elseif GetQuestLogTitle then
            local title, level, _, header, _, complete, _, id = GetQuestLogTitle(index)
            info = { title = title, level = level, isHeader = header, questID = id,
                isComplete = complete == 1 or complete == true, failed = complete == -1 }
        end
        if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
            local id = info.questID
            local complete = info.isComplete
            if log.IsComplete then complete = log.IsComplete(id) end
            local failed = info.failed or (log.IsFailed and log.IsFailed(id))
            if not failed then
                local reward
                if GetQuestLogRewardXP then
                    local ok, value = pcall(GetQuestLogRewardXP, id)
                    if ok and type(value) == "number" and value >= 0 then reward = value end
                end
                -- Missing reward data is unknown, never silently counted as zero.
                if reward == nil then
                    quests.unknown = quests.unknown + 1
                elseif complete then
                    quests.ready = quests.ready + reward
                else
                    quests.ongoing = quests.ongoing + reward
                end
                quests.rows[#quests.rows + 1] = {
                    title = info.title or ("Quest " .. id), xp = reward, complete = complete,
                }
            end
        end
    end
end

local function Tooltip()
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Till Next Level", 0.35, 0.81, 1)
    local maximum, xp = UnitXPMax("player"), UnitXP("player")
    local rate = addon.Rate(session, GetTime())
    GameTooltip:AddDoubleLine(T("XP restante", "XP remaining"), number(math.max(0, maximum - xp)), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("XP gagnée cette session", "Session XP gained"), number(session.gained))
    GameTooltip:AddDoubleLine(T("Durée de la session", "Session duration"), duration(GetTime() - session.started))
    GameTooltip:AddDoubleLine(T("XP / heure", "XP / hour"), number(rate))
    GameTooltip:AddDoubleLine(T("Temps avant le niveau suivant", "Time to next level"), rate > 0 and duration(math.max(0, maximum - xp) / rate * 3600) or "--")
    GameTooltip:AddDoubleLine(T("Après les quêtes terminées", "After completed quests"), rate > 0 and duration(math.max(0, maximum - xp - quests.ready) / rate * 3600) or "--")
    GameTooltip:AddDoubleLine(T("Bonus de repos disponible", "Rested XP available"), number(GetXPExhaustion() or 0))
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("Vert : prêtes à rendre · Or : en cours", "Green: ready to turn in · Gold: in progress"), 0.8, 0.8, 0.8)
    for _, quest in ipairs(quests.rows) do
        local r, g, b = 1, 0.76, 0.3
        if quest.complete then r, g, b = 0.3, 0.9, 0.55 end
        GameTooltip:AddDoubleLine(quest.title, quest.xp and (number(quest.xp) .. " XP") or "?", r, g, b, r, g, b)
    end
    if quests.unknown > 0 then
        GameTooltip:AddLine(T("XP indisponible pour certaines quêtes : total partiel.", "Some quest rewards are unavailable: partial total."), 1, 0.6, 0.3, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("Maj + glisser : déplacer · /tnl : commandes", "Shift + drag: move · /tnl: commands"), 0.65, 0.65, 0.65)
    GameTooltip:Show()
end

local function ResetSession()
    session = addon.NewSession(GetTime(), UnitLevel("player"), UnitXP("player"), UnitXPMax("player"))
end

local function Refresh()
    if not frame then return end
    local xp, maximum, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if addon.Observe(session, level, xp, maximum) == false then ResetSession() end
    local capped = maximum <= 0 or (IsXPUserDisabled and IsXPUserDisabled())
    if GetMaxPlayerLevel and level >= GetMaxPlayerLevel() then capped = true end
    local current, ready, ongoing = addon.Forecast(xp, maximum, quests.ready, quests.ongoing)
    local width = frame.bar:GetWidth()
    local function segment(texture, start, fraction)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", frame.bar, "TOPLEFT", width * start, 0)
        texture:SetPoint("BOTTOMLEFT", frame.bar, "BOTTOMLEFT", width * start, 0)
        texture:SetWidth(math.max(0.01, width * fraction))
        texture:SetShown(fraction > 0 and not capped)
    end
    segment(frame.actual, 0, current)
    segment(frame.ready, current, ready)
    segment(frame.ongoing, current + ready, ongoing)
    if capped then
        frame.title:SetText(string.format(T("Niveau %d · XP désactivée", "Level %d · XP disabled"), level))
        frame.stats:SetText("Till Next Level")
        frame.forecast:SetText("")
    else
        frame.title:SetText(string.format(T("Niv. %d   %s / %s XP   (%.1f%%)", "Lv. %d   %s / %s XP   (%.1f%%)"), level, number(xp), number(maximum), current * 100))
        local rate = addon.Rate(session, GetTime())
        frame.stats:SetText(string.format(T("%s XP / h   ·   Prochain niveau : %s", "%s XP / h   ·   Next level: %s"), number(rate), rate > 0 and duration((maximum - xp) / rate * 3600) or "--"))
        frame.forecast:SetText(string.format(T("Prêtes : +%s   ·   En cours : +%s%s", "Ready: +%s   ·   In progress: +%s%s"), number(quests.ready), number(quests.ongoing), quests.unknown > 0 and "   (?)" or ""))
    end
    frame:SetShown(not db.hidden)
    if GameTooltip:IsOwned(frame) then Tooltip() end
end

local function Position()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or -180)
end

local function CreateBar()
    frame = CreateFrame("Frame", "TillNextLevelFrame", UIParent)
    frame:SetSize(460, 90)
    frame:SetScale(db.scale or 1)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.035, 0.045, 0.065, 0.94)
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2)
    accent:SetColorTexture(0.35, 0.81, 1, 1)
    frame.bar = CreateFrame("Frame", nil, frame)
    frame.bar:SetPoint("TOPLEFT", 12, -31)
    frame.bar:SetPoint("TOPRIGHT", -12, -31)
    frame.bar:SetHeight(15)
    local track = frame.bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.12, 0.14, 0.18, 1)
    local function fill(r, g, b)
        local texture = frame.bar:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(WHITE)
        texture:SetVertexColor(r, g, b, 1)
        return texture
    end
    frame.actual = fill(0.35, 0.65, 1)
    frame.ready = fill(0.3, 0.85, 0.5)
    frame.ongoing = fill(1, 0.73, 0.25)
    local function label(y, font)
        local text = frame:CreateFontString(nil, "OVERLAY", font)
        text:SetPoint("TOPLEFT", 12, y)
        text:SetPoint("TOPRIGHT", -12, y)
        text:SetJustifyH("CENTER")
        return text
    end
    frame.title = label(-12, "GameFontHighlight")
    frame.stats = label(-51, "GameFontHighlightSmall")
    frame.forecast = label(-70, "GameFontHighlightSmall")
    frame.forecast:SetTextColor(0.8, 0.85, 0.9)
    frame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not db.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        db.x, db.y = x - parentX / scale, y - parentY / scale
        Position()
    end)
    frame:SetScript("OnEnter", Tooltip)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Position()
end

SLASH_TILLNEXTLEVEL1 = "/tnl"
SLASH_TILLNEXTLEVEL2 = "/tillnextlevel"
SlashCmdList.TILLNEXTLEVEL = function(input)
    if not db then return end
    local command, argument = input:lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "reset" then ResetSession(); message(T("Session réinitialisée.", "Session reset."))
    elseif command == "show" then db.hidden = false
    elseif command == "hide" then db.hidden = true
    elseif command == "lock" then db.locked = true; message(T("Position verrouillée.", "Position locked."))
    elseif command == "unlock" then db.locked = false; message(T("Maj + glisser pour déplacer.", "Shift + drag to move."))
    elseif command == "center" then db.x, db.y = 0, -180; Position()
    elseif command == "scale" then
        local scale = tonumber(argument)
        if scale and scale >= 0.5 and scale <= 2 then
            db.scale = scale; frame:SetScale(scale); Position()
        else message(T("Utilisation : /tnl scale 0.5 à 2", "Usage: /tnl scale 0.5 to 2")) end
    else message("/tnl show | hide | reset | lock | unlock | center | scale 1") end
    Refresh()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_LOG_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == addonName then
            TillNextLevelDB = type(TillNextLevelDB) == "table" and TillNextLevelDB or {}
            db = TillNextLevelDB
            if type(db.scale) ~= "number" or db.scale < 0.5 or db.scale > 2 then db.scale = 1 end
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        ResetSession(); CreateBar(); ScanQuests(); questDirty = false; Refresh()
        return
    end
    if not frame then return end
    if event == "QUEST_LOG_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" then
        questDirty = true
    end
    if event ~= "QUEST_LOG_UPDATE" and (event ~= "PLAYER_XP_UPDATE" or unit == "player") then Refresh() end
end)
events:SetScript("OnUpdate", function(_, delta)
    if not frame then return end
    elapsed, questElapsed = elapsed + delta, questElapsed + delta
    -- Throttle quest scans independently from the once-per-second rate display.
    if questDirty and questElapsed >= 0.5 then
        questDirty, questElapsed = false, 0
        ScanQuests(); Refresh()
    end
    if elapsed >= 1 then elapsed = 0; Refresh() end
end)
