local addonName, addon = ...
local frame, session, db
local quests = { ready = 0, ongoing = 0, readyCount = 0, ongoingCount = 0, unknown = 0, rows = {} }
local questDirty, questElapsed, elapsed = true, 0, 0
local WHITE = "Interface\\Buttons\\WHITE8X8"
local L = addon.L
local message
local blizzardBars = {}
local function ApplyBlizzardVisibility()
    if not db then return end
    local function track(bar, eligible)
        if (type(bar) ~= "table" and type(bar) ~= "userdata")
            or type(bar.GetAlpha) ~= "function" or type(bar.SetAlpha) ~= "function" then return end
        if db.hideBlizzardXP and eligible ~= false then
            if not blizzardBars[bar] then
                blizzardBars[bar] = { alpha = bar:GetAlpha() }
            end
            bar:SetAlpha(0)
        elseif blizzardBars[bar] then
            bar:SetAlpha(blizzardBars[bar].alpha)
            blizzardBars[bar] = nil
        end
    end
    track(MainMenuExpBar)
    track(MainMenuXPBar)
    track(ExperienceBar)
    track(XPBar)
    for _, name in ipairs({ "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local container = _G[name]
        if container then
            track(container.ExperienceBar)
            track(container.ExpBar)
            track(container.expBar)
            track(container.experienceBar)
            if type(container.GetBarFromTemplate) == "function" then
                for _, template in ipairs({ "ExpBarTemplate", "ExpStatusBarTemplate" }) do
                    local ok, bar = pcall(container.GetBarFromTemplate, container, template)
                    if ok then track(bar) end
                end
            end
            local experienceIndex = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum and StatusTrackingBarInfo.BarsEnum.Experience
            local experienceType = Enum and Enum.StatusTrackingBarType and Enum.StatusTrackingBarType.Experience
            if type(container.bars) == "table" then
                if experienceIndex then track(container.bars[experienceIndex]) end
                for _, bar in pairs(container.bars) do
                    if type(bar.GetType) == "function" then
                        local kind = bar:GetType()
                        if (experienceType and kind == experienceType) or kind == "EXPERIENCE" then track(bar) end
                    end
                end
            end
            -- Classic/Forever stores anonymous bars by BarsEnum, not GetType.
            -- Container artwork belongs to whichever bar is currently shown.
            if experienceIndex then
                local showingXP = container.shownBarIndex == experienceIndex
                -- Forever adds frame artwork outside the XP child itself.
                -- Hide its whole dedicated container only while it holds XP.
                if name ~= "StatusTrackingBarManager" then track(container, showingXP) end
                for _, field in ipairs({ "MainMenuBarTextures", "StandaloneTextures" }) do
                    if type(container[field]) == "table" then
                        for _, texture in ipairs(container[field]) do track(texture, showingXP) end
                    end
                end
            end
        end
    end
    if not db.hideBlizzardXP then
        for bar, original in pairs(blizzardBars) do
            bar:SetAlpha(original.alpha)
            blizzardBars[bar] = nil
        end
    end
end
local function BlizzardDiagnostics()
    for _, name in ipairs({ "MainMenuExpBar", "XPBar", "ExperienceBar", "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local object = _G[name]
        if object then
            message(name .. " alpha=" .. tostring(object:GetAlpha()) .. " index=" .. tostring(object.shownBarIndex))
            if object.GetChildren then
                for _, child in ipairs({ object:GetChildren() }) do
                    local kind = child.GetType and child:GetType()
                    message("  " .. tostring(child:GetName() or "anonymous") .. " type=" .. tostring(kind)
                        .. " alpha=" .. tostring(child:GetAlpha()))
                end
            end
        end
    end
end
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
message = function(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff59cfffTill Next Level|r : " .. text)
end

local function ScanQuests()
    local log = C_QuestLog or {}
    local count = log.GetNumQuestLogEntries or GetNumQuestLogEntries
    quests = { ready = 0, ongoing = 0, readyCount = 0, ongoingCount = 0, unknown = 0, rows = {} }
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
                if complete then quests.readyCount = quests.readyCount + 1
                else quests.ongoingCount = quests.ongoingCount + 1 end
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
                    id = id, order = index,
                }
            end
        end
    end
    table.sort(quests.rows,function(a,b)
        if not not a.complete ~= not not b.complete then return not not a.complete end
        return a.order < b.order
    end)
end

local function AccessibleNumber(value, fallback)
    -- Check secrecy before any comparison, conversion or arithmetic.
    if issecretvalue and issecretvalue(value) then return fallback end
    if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return fallback end
    return value
end

local function Tooltip()
    if type(frame.questTooltipColumns) ~= "table" then frame.questTooltipColumns = {} end
    for _, cells in ipairs(frame.questTooltipColumns) do for _, cell in ipairs(cells) do cell:Hide() end end
    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOP", frame, "BOTTOM", 0, -14)
    GameTooltip:ClearLines()
    GameTooltip:SetMinimumWidth(0)
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
    local columnRows, widths = {}, {0,0,0}
    for index, quest in ipairs(quests.rows) do
        local r, g, b = 1, 0.82, 0
        if quest.complete then r, g, b = 0.3, 0.85, 0.5 end
        local title, details, columns = quest.title
        if quest.complete then
            details, columns = addon.TurnInDetails(quest.id)
        end
        local values = {title, columns and columns.npc or "", columns and columns.location or details or ""}
        for i,value in ipairs(values) do values[i]=value:gsub("[\r\n]+"," ") end
        GameTooltip:AddDoubleLine(details and (title .. " — " .. details:gsub("[\r\n]+"," ")) or title,
            quest.xp and (number(quest.xp) .. " " .. L.xp) or "?", r, g, b, r, g, b)
        local lineNumber = GameTooltip:NumLines()
        local anchor = lineNumber and _G["GameTooltipTextLeft" .. lineNumber]
        if anchor then
            local cells = frame.questTooltipColumns[index]
            if not cells then
                cells = {}
                for i=1,3 do cells[i]=GameTooltip:CreateFontString(nil,"OVERLAY","GameTooltipText"); cells[i]:SetJustifyH("LEFT"); cells[i]:SetWordWrap(false) end
                frame.questTooltipColumns[index] = cells
            end
            for i,cell in ipairs(cells) do
                cell:SetWidth(0); cell:SetText(values[i]); cell:SetTextColor(r,g,b)
                local ok, measured = pcall(cell.GetStringWidth, cell)
                -- Tooltip anchors can make geometry secret even for public quest text.
                local estimate = select(2, values[i]:gsub("[^\128-\191]", "")) * 9
                widths[i]=math.max(widths[i],AccessibleNumber(ok and measured or nil, estimate))
            end
            columnRows[#columnRows+1]={cells=cells,anchor=anchor}
            anchor:SetText(" ")
        end
    end
    local total = widths[1]+widths[2]+widths[3]+48+100
    local available = math.max(200, AccessibleNumber(UIParent:GetWidth(), 1024)-40)
    if total > available then
        local factor=(available-148)/math.max(1,total-148)
        for i=1,3 do widths[i]=widths[i]*factor end
        total=available
    end
    if #columnRows > 0 then
        GameTooltip:SetMinimumWidth(total)
        for _,row in ipairs(columnRows) do
            local offset=0
            for i,cell in ipairs(row.cells) do
                cell:ClearAllPoints(); cell:SetPoint("TOPLEFT",row.anchor,"TOPLEFT",offset,0)
                cell:SetWidth(math.max(1,widths[i])); cell:Show()
                offset=offset+widths[i]+16
            end
        end
        if frame.questTooltipHideHook ~= true then
            frame.questTooltipHideHook=true
            GameTooltip:HookScript("OnHide",function() for _,cells in ipairs(frame.questTooltipColumns) do for _,cell in ipairs(cells) do cell:Hide() end end end)
        end
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
    frame.completed:SetText(L.completedQuests .. ": |cff4dd980" .. quests.readyCount .. " · " .. number(quests.ready) .. " " .. L.xp .. "|r" .. (quests.unknown > 0 and " (?)" or ""))
    frame.pending:SetText(L.ongoingQuests .. ": |cffffd100" .. quests.ongoingCount .. " · " .. number(quests.ongoing) .. " " .. L.xp .. "|r" .. (quests.unknown > 0 and " (?)" or ""))
    frame.rate:SetText(L.rate .. ": " .. number(rate))
    frame.level:SetWidth(capped and 400 or 135)
    frame.level:SetText(capped and string.format(L.capped, level) or string.format(L.compactLevel, level))
    frame.progress:SetText(capped and "" or (number(xp) .. " / " .. number(maximum)))
    frame.percent:SetText(capped and "--" or (addon.LocalizeDecimals(string.format("%.1f", current * 100)) .. "%"))
    if db.skin == "classic" then
        local remaining = math.max(0, maximum - xp)
        frame.title:SetText(capped and string.format(L.capped, level) or string.format(L.title,
            level, number(xp), number(maximum), addon.LocalizeDecimals(string.format("%.2f", current * 100)),
            number(remaining), addon.LocalizeDecimals(string.format("%.2f", (1-current)*100))))
        frame.stats:SetText(capped and "Till Next Level" or string.format(L.stats, number(rate),
            rate > 0 and duration(remaining / rate * 3600) or "--", number(quests.ready), number(quests.ongoing), quests.unknown > 0 and " (?)" or ""))
    end
    frame:SetShown(not db.hidden)
    if GameTooltip:IsOwned(frame) then Tooltip() end
end

local function Position()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or -180)
end

local skinOptions
local function ApplySkin()
    if not frame then return end
    local classic = db.skin == "classic"
    frame:SetSize(classic and 1000 or 520, classic and 102 or 94)
    frame.bar:ClearAllPoints()
    frame.bar:SetPoint("TOPLEFT", classic and 18 or 8, classic and -43 or -25)
    frame.bar:SetPoint("TOPRIGHT", classic and -18 or -8, classic and -43 or -25)
    frame.bar:SetHeight(classic and 24 or 28)
    frame.bar.background:SetVertexColor(classic and .3 or .08, classic and .3 or .09, classic and .3 or .11, classic and 1 or .95)
    local class = UnitClass and select(2, UnitClass("player"))
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    frame.actual:SetVertexColor(classic and .35 or (color and color.r or .04), classic and .65 or (color and color.g or .57), classic and 1 or (color and color.b or .86), 1)
    frame.ready:SetVertexColor(classic and .3 or 1, classic and .85 or .68, classic and .5 or .02, 1)
    frame.ongoing:SetVertexColor(classic and 1 or .52, classic and .73 or .38, classic and .25 or .12, 1)
    frame.shine:SetShown(not classic)
    frame.title:SetShown(classic); frame.stats:SetShown(classic)
    for _, key in ipairs({"time","session","level","progress","percent","completed","pending","rate"}) do frame[key]:SetShown(not classic) end
    if skinOptions then
        skinOptions.classic:SetText((classic and "✓ " or "") .. L.classicSkin)
        skinOptions.modern:SetText((not classic and "✓ " or "") .. L.modernSkin)
    end
    Position()
end

local function ShowSkinOptions()
    if not frame then return end
    if not skinOptions then
        skinOptions = CreateFrame("Frame", "TillNextLevelSkinOptions", UIParent)
        skinOptions:SetSize(270, 120); skinOptions:SetFrameStrata("DIALOG")
        skinOptions:SetPoint("CENTER")
        local bg = skinOptions:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetTexture(WHITE); bg:SetVertexColor(.06,.06,.08,.98)
        local title = skinOptions:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOP",0,-12); title:SetText(L.skinTitle)
        local close = CreateFrame("Button",nil,skinOptions,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",0,0)
        close:SetScript("OnClick",function() skinOptions:Hide() end)
        for index, skin in ipairs({"classic","modern"}) do
            local choice = skin
            local button = CreateFrame("Button",nil,skinOptions,"UIPanelButtonTemplate")
            button:SetSize(230,26); button:SetPoint("TOP",0,-38-(index-1)*34)
            button:SetScript("OnClick",function() db.skin=choice; ApplySkin(); Refresh(); skinOptions:Hide() end)
            skinOptions[skin]=button
        end
    end
    skinOptions:Show(); ApplySkin()
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
    frame.shine = shine
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
    frame.title = label(frame, "TOPLEFT", 18, -14, 964, 20, "CENTER")
    frame.stats = label(frame, "TOPLEFT", 18, -78, 964, 16, "CENTER")
    frame:SetScript("OnMouseUp",function(_,button) if button=="RightButton" then ShowSkinOptions() end end)
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
    ApplySkin()
end

SLASH_TILLNEXTLEVEL1 = "/tnl"
SLASH_TILLNEXTLEVEL2 = "/tillnextlevel"
SlashCmdList.TILLNEXTLEVEL = function(input)
    if not db then return end
    local command, argument = input:lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "options" then ShowSkinOptions()
    elseif command == "skin" then
        if argument == "classic" or argument == "modern" then db.skin=argument; ApplySkin()
        else message("/tnl skin classic | modern") end
    elseif command == "reset" then ResetSession(); message(L.reset)
    elseif command == "blizzard" then
        if argument == "status" then BlizzardDiagnostics()
        elseif argument == "hide" or argument == "show" then
            db.hideBlizzardXP = argument == "hide"
            ApplyBlizzardVisibility()
            message("/tnl blizzard " .. argument)
        else message("/tnl blizzard hide | show | status") end
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
    else message(L.help .. " | options | skin classic | skin modern | blizzard hide | blizzard show") end
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
            if db.skin ~= "classic" and db.skin ~= "modern" then db.skin = "modern" end
            if type(db.scale) ~= "number" or db.scale < 0.5 or db.scale > 2 then db.scale = 1 end
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        ResetSession(); CreateBar(); ScanQuests(); questDirty = false; Refresh(); ApplyBlizzardVisibility()
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
    if elapsed >= 1 then elapsed = 0; Refresh(); ApplyBlizzardVisibility() end
end)
