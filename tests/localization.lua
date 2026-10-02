local codes = { "enUS", "enGB", "frFR", "deDE", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW", "unknown" }
local function signature(text)
    return table.concat((function()
        local values = {}
        -- Ignore escaped percent signs in the title's percentage labels.
        text = text:gsub("%%%%", "")
        for specifier in text:gmatch("%%[%d%.]*[sdf]") do values[#values + 1] = specifier end
        return values
    end)(), ",")
end
for _, code in ipairs(codes) do
    function GetLocale() return code end
    local addon = {}
    assert(loadfile("Localization.lua"))("TillNextLevel", addon)
    for _, rows in pairs(addon.locales) do
        assert(#rows == #addon.localeKeys, "Incomplete translation")
        for index, text in ipairs(rows) do
            assert(signature(text) == signature(addon.locales.enUS[index]), "Mismatched format " .. code .. ": " .. addon.localeKeys[index])
        end
    end
    local title = string.format(addon.L.title, 10, "800", "1" .. addon.thousandsSeparator .. "000", addon.LocalizeDecimals("80.0"), "200", addon.LocalizeDecimals("20.0"))
    assert(title:find("1" .. addon.thousandsSeparator .. "000", 1, true))
    assert(title:find("20" .. addon.decimalSeparator .. "0%", 1, true))
    assert(string.format(addon.L.stats, "6000", "5 min", "150", "300", ""))
    assert(string.format(addon.L.quest, 123))
    assert(string.format(addon.L.minutes, 5))
    assert(string.format(addon.L.hours, 1, 5))
    if code == "unknown" then assert(addon.L.remaining == "XP remaining") end
end
print("localization: OK (12 locales + fallback)")
