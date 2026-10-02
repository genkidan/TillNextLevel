local _, addon = ...

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
