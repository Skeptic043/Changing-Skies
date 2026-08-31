ChangingSkies = ChangingSkies or {}

local Constants = ChangingSkies.Constants
local Log = ChangingSkies.Log
local Settings = {
    lastValidTemperaturePairs = {},
}

local OPTION_NAMES = {
    "EnableAddedWeather",
    "AddedWeatherFrequency",
    "AddedWeatherSeverity",
    "StormFrequency",
    "StormType",
    "StormLength",
    "AddedThunderFrequency",
    "AddedThunderScope",
    "CooldownMinimumHours",
    "CooldownMaximumHours",
    "EnableTemperatureAdjustment",
    "SpringColdTargetF",
    "SpringWarmTargetF",
    "SummerColdTargetF",
    "SummerWarmTargetF",
    "FallColdTargetF",
    "FallWarmTargetF",
    "WinterColdTargetF",
    "WinterWarmTargetF",
    "DebugLogging",
}

local function finiteNumber(value, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

local function integerInRange(value, minimum, maximum, fallback)
    local number = finiteNumber(value, fallback)
    number = math.floor(number)
    if number < minimum or number > maximum then
        return fallback
    end
    return number
end

local function copyPair(pair)
    return {
        coldTargetF = pair.coldTargetF,
        warmTargetF = pair.warmTargetF,
    }
end

local function defaultPair(profile)
    local defaults = Constants.DEFAULT_TEMPERATURE_RANGES_F[profile]
    return { coldTargetF = defaults.coldF, warmTargetF = defaults.warmF }
end

local function validTemperaturePair(coldValue, warmValue)
    local coldTargetF = finiteNumber(coldValue, nil)
    local warmTargetF = finiteNumber(warmValue, nil)
    if coldTargetF == nil or warmTargetF == nil or
        coldTargetF < -150.0 or coldTargetF > 200.0 or
        warmTargetF < -150.0 or warmTargetF > 200.0 or
        warmTargetF < coldTargetF then
        return nil
    end
    return { coldTargetF = coldTargetF, warmTargetF = warmTargetF }
end

local function readPair(source, profile)
    local pair = validTemperaturePair(
        source[profile .. "ColdTargetF"],
        source[profile .. "WarmTargetF"]
    )
    if pair ~= nil then
        Settings.lastValidTemperaturePairs[profile] = copyPair(pair)
    else
        local previous = Settings.lastValidTemperaturePairs[profile]
        pair = previous and copyPair(previous) or defaultPair(profile)
    end
    local reference = Constants.SEASON_TEMPERATURE_REFERENCES_F[profile]
    pair.coldDeltaF = pair.coldTargetF - reference.coldF
    pair.warmDeltaF = pair.warmTargetF - reference.warmF
    return pair
end

function Settings.readFromTable(source)
    source = type(source) == "table" and source or {}

    local minimumCooldown = finiteNumber(
        source.CooldownMinimumHours,
        Constants.DEFAULTS.cooldownMinimumHours
    )
    local maximumCooldown = finiteNumber(
        source.CooldownMaximumHours,
        Constants.DEFAULTS.cooldownMaximumHours
    )
    if minimumCooldown < 0.0 or maximumCooldown < minimumCooldown then
        Log.once(
            "invalid-cooldown",
            "Invalid added-weather cooldown range; using the conservative default range."
        )
        minimumCooldown = Constants.DEFAULTS.cooldownMinimumHours
        maximumCooldown = Constants.DEFAULTS.cooldownMaximumHours
    end

    local frequency = integerInRange(
        source.AddedWeatherFrequency,
        1,
        #Constants.WEATHER_PROBABILITIES,
        Constants.DEFAULTS.frequency
    )
    local severity = integerInRange(
        source.AddedWeatherSeverity,
        1,
        #Constants.SEVERITY_BANDS,
        Constants.DEFAULTS.severity
    )
    local stormFrequency = integerInRange(
        source.StormFrequency,
        1,
        #Constants.STORM_PROBABILITIES,
        Constants.DEFAULTS.stormFrequency
    )
    local stormType = integerInRange(
        source.StormType,
        1,
        5,
        Constants.DEFAULTS.stormType
    )
    local stormLength = integerInRange(
        source.StormLength,
        1,
        #Constants.STORM_DURATION_BANDS + 1,
        Constants.DEFAULTS.stormLength
    )
    local addedThunderFrequency = integerInRange(
        source.AddedThunderFrequency,
        1,
        #Constants.THUNDER_PROBABILITIES,
        Constants.DEFAULTS.addedThunderFrequency
    )
    local addedThunderScope = integerInRange(
        source.AddedThunderScope,
        1,
        3,
        Constants.DEFAULTS.addedThunderScope
    )

    local result = {
        enableAddedWeather = source.EnableAddedWeather == true,
        frequency = frequency,
        weatherProbability = Constants.WEATHER_PROBABILITIES[frequency],
        severity = severity,
        severityBand = Constants.SEVERITY_BANDS[severity],
        stormFrequency = stormFrequency,
        stormProbability = Constants.STORM_PROBABILITIES[stormFrequency],
        stormType = stormType,
        stormLength = stormLength,
        stormDurationBand = Constants.STORM_DURATION_BANDS[stormLength],
        addedThunderFrequency = addedThunderFrequency,
        addedThunderProbability = Constants.THUNDER_PROBABILITIES[addedThunderFrequency],
        addedThunderScope = addedThunderScope,
        cooldownMinimumHours = minimumCooldown,
        cooldownMaximumHours = maximumCooldown,
        enableTemperatureAdjustment = source.EnableTemperatureAdjustment == true,
        debugLogging = source.DebugLogging == true,
        temperatureProfiles = {
            Spring = readPair(source, "Spring"),
            Summer = readPair(source, "Summer"),
            Fall = readPair(source, "Fall"),
            Winter = readPair(source, "Winter"),
        },
    }
    Log.setDebugEnabled(result.debugLogging)
    return result
end

function Settings.read()
    local source = {}
    if type(SandboxVars) == "table" and type(SandboxVars.ChangingSkies) == "table" then
        for _, name in ipairs(OPTION_NAMES) do
            source[name] = SandboxVars.ChangingSkies[name]
        end
    end

    if type(getSandboxOptions) == "function" then
        local sandboxOptions = getSandboxOptions()
        if sandboxOptions ~= nil then
            for _, name in ipairs(OPTION_NAMES) do
                local option = sandboxOptions:getOptionByName("ChangingSkies." .. name)
                if option ~= nil then
                    local value = option:getValue()
                    if value ~= nil then
                        source[name] = value
                    end
                end
            end
        end
    end
    return Settings.readFromTable(source)
end

function Settings.profileForMonth(settings, month)
    local profileName = Constants.SEASON_PROFILE_BY_MONTH[month] or "Winter"
    return settings.temperatureProfiles[profileName], profileName
end

function Settings.resetValidationMemoryForTests()
    Settings.lastValidTemperaturePairs = {}
end

ChangingSkies.Settings = Settings
