local addonName, addon = ...
local frame, session, db
local quests = { ready = 0, ongoing = 0, unknown = 0, rows = {} }
local questDirty, questElapsed, elapsed = true, 0, 0
local WHITE = "Interface\\Buttons\\WHITE8X8"
local L = addon.L
local function number(value)
    local s = tostring(math.floor(value + 0.5))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1" .. addon.thousandsSeparator):reverse()
    if formatted:sub(1, 1) == addon.thousandsSeparator then formatted = formatted:sub(2) end
    return formatted
end
local function duration(seconds)
    if not seconds or seconds == math.huge then return "--" end
    local minutes = math.ceil(seconds / 60)
    if minutes < 60 then return string.format(L.minutes, minutes) end
    return string.format(L.hours, math.floor(minutes / 60), minutes % 60)
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
                    title = info.title or string.format(L.quest, id), xp = reward, complete = complete,
                }
            end
        end
    end
end

local function Tooltip()
    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOP", frame, "BOTTOM", 0, -14)
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Till Next Level", 0.35, 0.81, 1)
    local maximum, xp = UnitXPMax("player"), UnitXP("player")
    local rate = addon.Rate(session, GetTime())
    GameTooltip:AddDoubleLine(L.remaining, number(math.max(0, maximum - xp)), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.gained, number(session.gained))
    GameTooltip:AddDoubleLine(L.sessionDuration, duration(GetTime() - session.started))
    GameTooltip:AddDoubleLine(L.rate, number(rate))
    GameTooltip:AddDoubleLine(L.nextTime, rate > 0 and duration(math.max(0, maximum - xp) / rate * 3600) or "--")
    GameTooltip:AddDoubleLine(L.afterQuests, rate > 0 and duration(math.max(0, maximum - xp - quests.ready) / rate * 3600) or "--")
    GameTooltip:AddDoubleLine(L.rested, number(GetXPExhaustion() or 0))
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.legend, 0.8, 0.8, 0.8)
    for _, quest in ipairs(quests.rows) do
        local r, g, b = 0.75, 0.62, 0.35
        if quest.complete then r, g, b = 1, 0.76, 0.17 end
        GameTooltip:AddDoubleLine(quest.title, quest.xp and (number(quest.xp) .. " " .. L.xp) or "?", r, g, b, r, g, b)
    end
    if quests.unknown > 0 then
        GameTooltip:AddLine(L.partial, 1, 0.6, 0.3, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(db.locked and L.unlockHint or L.dragHint, 0.65, 0.65, 0.65)
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
    local rate = addon.Rate(session, GetTime())
    frame.time:SetText(L.nextTime .. ": " .. (not capped and rate > 0 and duration(math.max(0, maximum - xp) / rate * 3600) or "--"))
    frame.session:SetText(L.sessionDuration .. ": " .. duration(GetTime() - session.started))
    frame.completed:SetText(L.completedQuests .. ": |cffffc02b" .. number(quests.ready) .. "|r" .. (quests.unknown > 0 and " (?)" or ""))
    frame.pending:SetText(L.ongoingQuests .. ": |cffc09e59" .. number(quests.ongoing) .. "|r" .. (quests.unknown > 0 and " (?)" or ""))
    frame.rate:SetText(L.rate .. ": " .. number(rate))
    frame.level:SetWidth(capped and 400 or 135)
    frame.level:SetText(capped and string.format(L.capped, level) or string.format(L.compactLevel, level))
    frame.progress:SetText(capped and "" or (number(xp) .. " / " .. number(maximum)))
    frame.percent:SetText(capped and "--" or (addon.LocalizeDecimals(string.format("%.1f", current * 100)) .. "%"))
    frame:SetShown(not db.hidden)
    if GameTooltip:IsOwned(frame) then Tooltip() end
end

local function Position()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or -180)
end

local function CreateBar()
    frame = CreateFrame("Frame", "TillNextLevelFrame", UIParent)
    frame:SetSize(520, 94)
    frame:SetScale(db.scale or 1)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame.bar = CreateFrame("Frame", nil, frame)
    frame.bar:SetPoint("TOPLEFT", 8, -25)
    frame.bar:SetPoint("TOPRIGHT", -8, -25)
    frame.bar:SetHeight(28)
    frame.bar.background = frame.bar:CreateTexture(nil, "BACKGROUND")
    frame.bar.background:SetTexture(WHITE)
    frame.bar.background:SetVertexColor(0.08, 0.09, 0.11, 0.95)
    frame.bar.background:SetAllPoints(frame.bar)
    local function fill(r, g, b)
        local texture = frame.bar:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(WHITE)
        texture:SetVertexColor(r, g, b, 1)
        return texture
    end
    local class = UnitClass and select(2, UnitClass("player"))
    local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    frame.actual = fill(classColor and classColor.r or 0.04,
        classColor and classColor.g or 0.57, classColor and classColor.b or 0.86)
    frame.ready = fill(1, 0.68, 0.02)
    frame.ongoing = fill(0.52, 0.38, 0.12)
    local shine = frame.bar:CreateTexture(nil, "OVERLAY")
    shine:SetTexture(WHITE)
    shine:SetVertexColor(1, 1, 1, 0.10)
    shine:SetPoint("TOPLEFT", 0, 0)
    shine:SetPoint("TOPRIGHT", 0, 0)
    shine:SetHeight(3)
    local function label(parent, anchor, x, y, width, size, align, bright)
        local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        local font = text:GetFont()
        text:SetFont(font or STANDARD_TEXT_FONT, size, bright and "OUTLINE" or "")
        text:SetPoint(anchor, parent, anchor, x, y)
        text:SetWidth(width)
        text:SetJustifyH(align)
        text:SetWordWrap(false)
        local color = bright and 1 or 0.65
        text:SetTextColor(color, color, color)
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        return text
    end
    frame.time = label(frame, "TOPLEFT", 8, -4, 300, 12, "LEFT")
    frame.session = label(frame, "TOPRIGHT", -8, -4, 190, 12, "RIGHT")
    frame.level = label(frame.bar, "LEFT", 7, 0, 135, 15, "LEFT", true)
    frame.progress = label(frame.bar, "CENTER", 0, 0, 220, 15, "CENTER", true)
    frame.percent = label(frame.bar, "RIGHT", -7, 0, 70, 15, "RIGHT", true)
    frame.completed = label(frame, "BOTTOMLEFT", 8, 22, 330, 12, "LEFT")
    frame.rate = label(frame, "BOTTOMRIGHT", -8, 22, 165, 12, "RIGHT")
    frame.pending = label(frame, "BOTTOMLEFT", 8, 4, 330, 12, "LEFT")
    frame:SetScript("OnDragStart", function(self)
        if not db.locked then
            GameTooltip:Hide()
            self:StartMoving()
        end
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
    if command == "reset" then ResetSession(); message(L.reset)
    elseif command == "show" then db.hidden = false
    elseif command == "hide" then db.hidden = true
    elseif command == "lock" then db.locked = true; message(L.locked)
    elseif command == "unlock" then db.locked = false; message(L.move)
    elseif command == "center" then db.x, db.y = 0, -180; Position()
    elseif command == "scale" then
        local scale = tonumber((argument:gsub(",", ".")))
        if scale and scale >= 0.5 and scale <= 2 then
            db.scale = scale; frame:SetScale(scale); Position()
        else message(L.scaleUsage) end
    else message(L.help) end
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
