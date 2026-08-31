local testsRun = 0

local function fail(message)
    error(message, 2)
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        fail((message or "values differ") .. ": expected " .. tostring(expected) ..
            ", got " .. tostring(actual))
    end
end

local function assertNear(actual, expected, tolerance, message)
    if math.abs(actual - expected) > tolerance then
        fail((message or "values differ") .. ": expected " .. tostring(expected) ..
            ", got " .. tostring(actual))
    end
end

local function assertContains(actual, expected, message)
    if string.find(actual, expected, 1, true) == nil then
        fail((message or "text not found") .. ": expected " .. tostring(expected) ..
            " in " .. tostring(actual))
    end
end

local function test(name, callback)
    callback()
    testsRun = testsRun + 1
    print("PASS " .. name)
end

ClimateManager = {
    FLOAT_TEMPERATURE = 4,
    BOOL_IS_SNOW = 0,
    winterIsComing = false,
}

GameTime = {
    instance = { month = 0 },
}
function GameTime.instance:getMonth() return self.month end
function GameTime.getInstance() return GameTime.instance end

local function newClimateFloat()
    local value = {
        enableModded = false,
        moddedValue = 0.0,
        moddedInterpolation = 0.0,
        enableAdmin = false,
        enableOverride = false,
        override = 0.0,
        overrideInterpolation = 0.0,
    }
    function value:setEnableModded(enabled) self.enableModded = enabled end
    function value:setModdedValue(number) self.moddedValue = number end
    function value:setModdedInterpolate(number) self.moddedInterpolation = number end
    function value:isEnableAdmin() return self.enableAdmin end
    function value:isEnableOverride() return self.enableOverride end
    function value:getOverride() return self.override end
    function value:getOverrideInterpolate() return self.overrideInterpolation end
    function value:setOverride(number, interpolation)
        self.override = number
        self.overrideInterpolation = interpolation
        self.enableOverride = true
    end
    return value
end

local function newClimateBool()
    local value = { enableModded = false, moddedValue = false }
    function value:setEnableModded(enabled) self.enableModded = enabled end
    function value:setModdedValue(boolean) self.moddedValue = boolean end
    return value
end

local function temperatureSettings(coldDeltaF, warmDeltaF)
    local pair = { coldDeltaF = coldDeltaF, warmDeltaF = warmDeltaF }
    return {
        enableTemperatureAdjustment = true,
        temperatureProfiles = {
            Spring = pair,
            Summer = pair,
            Fall = pair,
            Winter = pair,
        },
    }
end

local function newTemperatureManager(options)
    local temperatureFloat = newClimateFloat()
    temperatureFloat.enableAdmin = options.admin == true
    temperatureFloat.enableOverride = options.overrideEnabled == true
    temperatureFloat.override = options.override or 0.0
    temperatureFloat.overrideInterpolation = options.overrideInterpolation or 0.0
    local snowBool = newClimateBool()
    local weatherPeriod = { running = options.weatherRunning == true }
    function weatherPeriod:isRunning() return self.running end
    local clean = {
        temperature = options.vanillaTemperature or 0.0,
        airMass = options.airMass or 0.0,
    }
    function clean:getTemperature() return self.temperature end
    function clean:getAirMassTemperature() return self.airMass end

    local manager = {}
    function manager:getClimateFloat(_) return temperatureFloat end
    function manager:getClimateBool(_) return snowBool end
    function manager:getClimateValuesCopy() return clean end
    function manager:getWeatherPeriod() return weatherPeriod end
    return manager, temperatureFloat, snowBool
end

local function weatherSettings()
    return {
        enableAddedWeather = true,
        weatherProbability = 1.0,
        severityBand = { minimum = 0.41, maximum = 0.55 },
        stormProbability = 0.0,
        stormType = 1,
        stormLength = 2,
        stormDurationBand = { minimum = 12.0, maximum = 24.0 },
        cooldownMinimumHours = 2.0,
        cooldownMaximumHours = 4.0,
    }
end

local function newWeatherManager(initiallyRunning, startsWhenTriggered, options)
    options = options or {}
    local period = { running = initiallyRunning == true }
    function period:isRunning() return self.running end
    local manager = { triggerCount = 0, stageTriggerCount = 0 }
    function manager:getWeatherPeriod() return period end
    function manager:getSeason()
        if options.seasonUnavailable then
            return nil
        end
        local season = { id = options.erosionSeasonId }
        function season:getSeason() return self.id end
        return season
    end
    function manager:triggerCustomWeather(strength, coldFront)
        self.triggerCount = self.triggerCount + 1
        self.lastWeatherStrength = strength
        self.lastWeatherColdFront = coldFront
        if startsWhenTriggered then
            period.running = true
        end
        return true
    end
    function manager:triggerCustomWeatherStage(stageId, durationHours)
        self.stageTriggerCount = self.stageTriggerCount + 1
        self.lastStageId = stageId
        self.lastStageDurationHours = durationHours
        if startsWhenTriggered then
            period.running = true
        end
        return true
    end
    return manager, period
end

local function sequenceRandom(values)
    local index = 0
    return function()
        index = index + 1
        return values[index] or 0.0
    end
end

local function newPlayer(x, y)
    local player = { x = x, y = y }
    function player:getX() return self.x end
    function player:getY() return self.y end
    return player
end

local function newThunderManager(weatherRunning, hasSystem, options)
    options = options or {}
    local period = {
        running = weatherRunning == true,
        currentStageId = options.currentStageId or 0,
        thunderStorm = options.thunderStorm == true,
        tropicalStorm = options.tropicalStorm == true,
    }
    function period:isRunning() return self.running end
    function period:getCurrentStageID() return self.currentStageId end
    function period:isThunderStorm() return self.thunderStorm end
    function period:isTropicalStorm() return self.tropicalStorm end
    local events = {}
    local thunderSystem = nil
    if hasSystem ~= false then
        thunderSystem = {}
        function thunderSystem:triggerThunderEvent(x, y, sound, lightning, rumble)
            events[#events + 1] = {
                x = x,
                y = y,
                sound = sound,
                lightning = lightning,
                rumble = rumble,
            }
        end
    end
    local manager = {}
    function manager:getWeatherPeriod() return period end
    function manager:getThunderStorm() return thunderSystem end
    return manager, events
end

local function installPlayerEnvironment(server, players)
    local previousIsServer = isServer
    local previousGetOnlinePlayers = getOnlinePlayers
    local previousGetNumActivePlayers = getNumActivePlayers
    local previousGetSpecificPlayer = getSpecificPlayer
    isServer = function() return server == true end
    if server then
        local online = { players = players }
        function online:size() return self.players.count or #self.players end
        function online:get(index) return self.players[index + 1] end
        getOnlinePlayers = function() return online end
        getNumActivePlayers = nil
        getSpecificPlayer = nil
    else
        getOnlinePlayers = nil
        getNumActivePlayers = function() return players.count or #players end
        getSpecificPlayer = function(index) return players[index + 1] end
    end
    return function()
        isServer = previousIsServer
        getOnlinePlayers = previousGetOnlinePlayers
        getNumActivePlayers = previousGetNumActivePlayers
        getSpecificPlayer = previousGetSpecificPlayer
    end
end

local function newSnowDiagnosticManager(options)
    local period = { running = options.weatherRunning == true }
    function period:isRunning() return self.running end
    local season = { seasonFive = options.seasonFive == true }
    function season:isSeason(seasonId)
        return seasonId == 5 and self.seasonFive
    end
    local manager = {}
    function manager:getPrecipitationIsSnow() return options.composedSnow end
    function manager:getPrecipitationIntensity() return options.precipitationIntensity end
    function manager:getSnowStrength() return options.snowStrength end
    function manager:getSnowFracNow() return options.snowFracNow end
    function manager:getSeason() return season end
    function manager:getWeatherPeriod() return period end
    return manager
end

test("snow diagnostics stay silent when debug logging is off", function()
    ChangingSkies.SnowDiagnostics.resetForTests()
    local emitted = {}
    local previousDebug = ChangingSkies.Log.debug
    ChangingSkies.Log.debug = function(message) emitted[#emitted + 1] = message end
    local line = ChangingSkies.SnowDiagnostics.emit(
        {},
        { debugLogging = false },
        { applied = true, correctedTemperature = -5.0 },
        100.0
    )
    ChangingSkies.Log.debug = previousDebug
    assertEqual(line, nil)
    assertEqual(#emitted, 0)
end)

test("snow diagnostics report all fields once per ten-minute slot", function()
    ChangingSkies.SnowDiagnostics.resetForTests()
    local previousGetCell = getCell
    local cell = {}
    function cell:getSnowTarget() return 42 end
    getCell = function() return cell end
    local emitted = {}
    local previousDebug = ChangingSkies.Log.debug
    ChangingSkies.Log.debug = function(message) emitted[#emitted + 1] = message end
    local manager = newSnowDiagnosticManager({
        composedSnow = true,
        precipitationIntensity = 0.75,
        snowStrength = 0.6,
        snowFracNow = 0.4,
        seasonFive = true,
        weatherRunning = true,
    })
    local first = ChangingSkies.SnowDiagnostics.emit(
        manager,
        { debugLogging = true },
        { applied = true, correctedTemperature = -4.5 },
        120.0
    )
    local duplicate = ChangingSkies.SnowDiagnostics.emit(
        manager,
        { debugLogging = true },
        { applied = true, correctedTemperature = -4.5 },
        120.1
    )
    ChangingSkies.SnowDiagnostics.emit(
        manager,
        { debugLogging = true },
        { applied = true, correctedTemperature = -4.5 },
        120.2
    )
    ChangingSkies.Log.debug = previousDebug
    getCell = previousGetCell

    assertEqual(first,
        "SnowDiag previousCompletedTick.composedSnow=true " ..
        "previousCompletedTick.precipitationIntensity=0.75 " ..
        "previousCompletedTick.snowStrength=0.6 " ..
        "previousCompletedTick.snowFracNow=0.4 " ..
        "previousCompletedTick.cellSnowTarget=42 " ..
        "previousCompletedTick.season5GroundRendererEligible=true " ..
        "previousCompletedTick.weatherPeriodRunning=true " ..
        "newTick.csTemperatureStatus=applied " ..
        "newTick.csCorrectedTemperatureC=-4.5 " ..
        "newTick.csRequestedSnowTarget=true")
    assertEqual(duplicate, nil)
    assertEqual(#emitted, 2)
end)

test("snow diagnostics safely label an unavailable cell", function()
    ChangingSkies.SnowDiagnostics.resetForTests()
    local previousGetCell = getCell
    getCell = nil
    local emitted = {}
    local previousDebug = ChangingSkies.Log.debug
    ChangingSkies.Log.debug = function(message) emitted[#emitted + 1] = message end
    local line = ChangingSkies.SnowDiagnostics.emit(
        newSnowDiagnosticManager({
            composedSnow = false,
            precipitationIntensity = 0.0,
            snowStrength = 0.0,
            snowFracNow = 0.0,
            seasonFive = false,
            weatherRunning = false,
        }),
        { debugLogging = true },
        { applied = false, reason = "admin" },
        200.0
    )
    ChangingSkies.Log.debug = previousDebug
    getCell = previousGetCell

    assertContains(line, "previousCompletedTick.cellSnowTarget=unavailable")
    assertContains(line, "newTick.csTemperatureStatus=relinquished:admin")
    assertContains(line, "newTick.csCorrectedTemperatureC=unavailable")
    assertContains(line, "newTick.csRequestedSnowTarget=unavailable")
    assertEqual(#emitted, 1)
end)

test("added-weather fallback default is enabled", function()
    assertEqual(ChangingSkies.Constants.DEFAULTS.enableAddedWeather, true)
    assertEqual(ChangingSkies.Constants.DEFAULTS.stormFrequency, 1)
    assertEqual(ChangingSkies.Constants.DEFAULTS.addedThunderFrequency, 1)
    assertEqual(ChangingSkies.Constants.DEFAULTS.addedThunderScope, 1)
end)

test("new storm and thunder settings default Off with validated fallbacks", function()
    local settings = ChangingSkies.Settings.readFromTable({})
    assertEqual(settings.stormFrequency, 1)
    assertEqual(settings.stormProbability, 0.0)
    assertEqual(settings.stormType, 1)
    assertEqual(settings.stormLength, 2)
    assertEqual(settings.stormDurationBand.minimum, 12.0)
    assertEqual(settings.stormDurationBand.maximum, 24.0)
    assertEqual(settings.addedThunderFrequency, 1)
    assertEqual(settings.addedThunderProbability, 0.0)
    assertEqual(settings.addedThunderScope, 1)
end)

local function sandboxOption(value)
    local option = { value = value }
    function option:getValue() return self.value end
    return option
end

local function sandboxOptions(values)
    local options = { values = values }
    function options:getOptionByName(name)
        local value = self.values[name]
        if value == nil then
            return nil
        end
        return sandboxOption(value)
    end
    return options
end

test("live sandbox options replace the stale SandboxVars snapshot", function()
    local previousSandboxVars = SandboxVars
    local previousGetSandboxOptions = getSandboxOptions
    SandboxVars = {
        ChangingSkies = {
            EnableAddedWeather = false,
            AddedWeatherFrequency = 2,
            AddedWeatherSeverity = 2,
            StormFrequency = 2,
            StormType = 2,
            StormLength = 3,
            AddedThunderFrequency = 4,
            AddedThunderScope = 2,
            CooldownMinimumHours = 24.0,
            CooldownMaximumHours = 72.0,
            EnableTemperatureAdjustment = true,
            SpringColdTargetF = 37.0,
            SpringWarmTargetF = 66.0,
            SummerColdTargetF = 60.0,
            SummerWarmTargetF = 89.0,
            FallColdTargetF = 42.0,
            FallWarmTargetF = 71.0,
            WinterColdTargetF = 19.0,
            WinterWarmTargetF = 48.0,
            DebugLogging = false,
        },
    }
    local live = sandboxOptions({
        ["ChangingSkies.EnableAddedWeather"] = true,
        ["ChangingSkies.AddedWeatherFrequency"] = 6,
        ["ChangingSkies.AddedWeatherSeverity"] = 6,
        ["ChangingSkies.StormFrequency"] = 7,
        ["ChangingSkies.StormType"] = 4,
        ["ChangingSkies.StormLength"] = 4,
        ["ChangingSkies.AddedThunderFrequency"] = 5,
        ["ChangingSkies.AddedThunderScope"] = 3,
        ["ChangingSkies.CooldownMinimumHours"] = 0.0,
        ["ChangingSkies.CooldownMaximumHours"] = 5.0,
        ["ChangingSkies.EnableTemperatureAdjustment"] = false,
        ["ChangingSkies.SpringColdTargetF"] = 36.5,
        ["ChangingSkies.SpringWarmTargetF"] = 67.3,
        ["ChangingSkies.SummerColdTargetF"] = 58.2,
        ["ChangingSkies.SummerWarmTargetF"] = 91.0,
        ["ChangingSkies.FallColdTargetF"] = 39.4,
        ["ChangingSkies.FallWarmTargetF"] = 74.2,
        ["ChangingSkies.WinterColdTargetF"] = 15.9,
        ["ChangingSkies.WinterWarmTargetF"] = 52.7,
        ["ChangingSkies.DebugLogging"] = true,
    })
    getSandboxOptions = function() return live end

    local settings = ChangingSkies.Settings.read()
    assertEqual(settings.enableAddedWeather, true)
    assertEqual(settings.frequency, 6)
    assertEqual(settings.severity, 6)
    assertEqual(settings.stormFrequency, 7)
    assertEqual(settings.stormProbability, 1.0)
    assertEqual(settings.stormType, 4)
    assertEqual(settings.stormLength, 4)
    assertEqual(settings.stormDurationBand.minimum, 48.0)
    assertEqual(settings.stormDurationBand.maximum, 96.0)
    assertEqual(settings.addedThunderFrequency, 5)
    assertEqual(settings.addedThunderProbability, 1.0)
    assertEqual(settings.addedThunderScope, 3)
    assertEqual(settings.cooldownMinimumHours, 0.0)
    assertEqual(settings.cooldownMaximumHours, 5.0)
    assertEqual(settings.enableTemperatureAdjustment, false)
    assertNear(settings.temperatureProfiles.Spring.coldDeltaF, -1.0, 0.0001)
    assertNear(settings.temperatureProfiles.Spring.warmDeltaF, 1.0, 0.0001)
    assertNear(settings.temperatureProfiles.Summer.coldDeltaF, -2.0, 0.0001)
    assertNear(settings.temperatureProfiles.Summer.warmDeltaF, 2.0, 0.0001)
    assertNear(settings.temperatureProfiles.Fall.coldDeltaF, -3.0, 0.0001)
    assertNear(settings.temperatureProfiles.Fall.warmDeltaF, 3.0, 0.0001)
    assertNear(settings.temperatureProfiles.Winter.coldDeltaF, -4.0, 0.0001)
    assertNear(settings.temperatureProfiles.Winter.warmDeltaF, 4.0, 0.0001)
    assertEqual(settings.debugLogging, true)

    ChangingSkies.Log.setDebugEnabled(false)
    SandboxVars = previousSandboxVars
    getSandboxOptions = previousGetSandboxOptions
end)

test("missing live options fall back per option to SandboxVars", function()
    local previousSandboxVars = SandboxVars
    local previousGetSandboxOptions = getSandboxOptions
    SandboxVars = {
        ChangingSkies = {
            EnableAddedWeather = false,
            AddedWeatherFrequency = 2,
            AddedWeatherSeverity = 4,
            StormFrequency = 2,
            StormType = 2,
            StormLength = 3,
            AddedThunderFrequency = 4,
            AddedThunderScope = 2,
            CooldownMinimumHours = 7.0,
            CooldownMaximumHours = 9.0,
        },
    }
    local live = sandboxOptions({
        ["ChangingSkies.AddedWeatherFrequency"] = 6,
        ["ChangingSkies.StormFrequency"] = 7,
    })
    getSandboxOptions = function() return live end

    local settings = ChangingSkies.Settings.read()
    assertEqual(settings.enableAddedWeather, false)
    assertEqual(settings.frequency, 6)
    assertEqual(settings.severity, 4)
    assertEqual(settings.stormFrequency, 7)
    assertEqual(settings.stormType, 2)
    assertEqual(settings.stormLength, 3)
    assertEqual(settings.addedThunderFrequency, 4)
    assertEqual(settings.addedThunderScope, 2)
    assertEqual(settings.cooldownMinimumHours, 7.0)
    assertEqual(settings.cooldownMaximumHours, 9.0)

    SandboxVars = previousSandboxVars
    getSandboxOptions = previousGetSandboxOptions
end)

test("absent live sandbox API falls back to SandboxVars", function()
    local previousSandboxVars = SandboxVars
    local previousGetSandboxOptions = getSandboxOptions
    SandboxVars = {
        ChangingSkies = {
            EnableAddedWeather = true,
            AddedWeatherFrequency = 5,
            AddedWeatherSeverity = 5,
            StormFrequency = 6,
            StormType = 3,
            StormLength = 1,
            AddedThunderFrequency = 5,
            AddedThunderScope = 3,
            CooldownMinimumHours = 1.0,
            CooldownMaximumHours = 3.0,
            EnableTemperatureAdjustment = false,
        },
    }
    getSandboxOptions = nil

    local settings = ChangingSkies.Settings.read()
    assertEqual(settings.enableAddedWeather, true)
    assertEqual(settings.frequency, 5)
    assertEqual(settings.severity, 5)
    assertEqual(settings.stormFrequency, 6)
    assertEqual(settings.stormType, 3)
    assertEqual(settings.stormLength, 1)
    assertEqual(settings.addedThunderFrequency, 5)
    assertEqual(settings.addedThunderScope, 3)
    assertEqual(settings.cooldownMinimumHours, 1.0)
    assertEqual(settings.cooldownMaximumHours, 3.0)
    assertEqual(settings.enableTemperatureAdjustment, false)

    SandboxVars = previousSandboxVars
    getSandboxOptions = previousGetSandboxOptions
end)

test("all calendar months map to their fixed seasons", function()
    local settings = {
        temperatureProfiles = {
            Spring = {},
            Summer = {},
            Fall = {},
            Winter = {},
        },
    }
    local expected = {
        [0] = "Winter",
        [1] = "Winter",
        [2] = "Spring",
        [3] = "Spring",
        [4] = "Spring",
        [5] = "Summer",
        [6] = "Summer",
        [7] = "Summer",
        [8] = "Fall",
        [9] = "Fall",
        [10] = "Fall",
        [11] = "Winter",
    }
    for month = 0, 11 do
        local _, profileName = ChangingSkies.Settings.profileForMonth(settings, month)
        assertEqual(profileName, expected[month], "calendar month " .. tostring(month))
    end
end)

test("rounded default ranges populate all downstream seasonal fields", function()
    ChangingSkies.Settings.resetValidationMemoryForTests()
    local settings = ChangingSkies.Settings.readFromTable({})
    local expected = {
        Spring = { 37.0, 66.0, -0.5, -0.3 },
        Summer = { 60.0, 89.0, -0.2, 0.0 },
        Fall = { 42.0, 71.0, -0.4, -0.2 },
        Winter = { 19.0, 48.0, -0.9, -0.7 },
    }
    for profileName, values in pairs(expected) do
        local pair = settings.temperatureProfiles[profileName]
        assertEqual(pair.coldTargetF, values[1])
        assertEqual(pair.warmTargetF, values[2])
        assertNear(pair.coldDeltaF, values[3], 0.0001)
        assertNear(pair.warmDeltaF, values[4], 0.0001)
    end
end)

test("numeric target endpoints accept signed decimals and equal values", function()
    ChangingSkies.Settings.resetValidationMemoryForTests()
    local settings = ChangingSkies.Settings.readFromTable({
        SpringColdTargetF = 30.5,
        SpringWarmTargetF = 70.25,
        SummerColdTargetF = -20.0,
        SummerWarmTargetF = -10.0,
        FallColdTargetF = 40.25,
        FallWarmTargetF = 75.5,
        WinterColdTargetF = 0.0,
        WinterWarmTargetF = 0.0,
    })
    assertEqual(settings.temperatureProfiles.Spring.coldTargetF, 30.5)
    assertEqual(settings.temperatureProfiles.Spring.warmTargetF, 70.25)
    assertEqual(settings.temperatureProfiles.Summer.coldTargetF, -20.0)
    assertEqual(settings.temperatureProfiles.Summer.warmTargetF, -10.0)
    assertEqual(settings.temperatureProfiles.Fall.coldTargetF, 40.25)
    assertEqual(settings.temperatureProfiles.Fall.warmTargetF, 75.5)
    assertEqual(settings.temperatureProfiles.Winter.coldTargetF, 0.0)
    assertEqual(settings.temperatureProfiles.Winter.warmTargetF, 0.0)
    assertNear(settings.temperatureProfiles.Summer.coldDeltaF, -80.2, 0.0001)
    assertNear(settings.temperatureProfiles.Summer.warmDeltaF, -99.0, 0.0001)
end)

test("incomplete and reversed numeric edits preserve the last valid pair", function()
    ChangingSkies.Settings.resetValidationMemoryForTests()
    local valid = ChangingSkies.Settings.readFromTable({
        SpringColdTargetF = 30.0,
        SpringWarmTargetF = 70.0,
    })
    assertEqual(valid.temperatureProfiles.Spring.coldTargetF, 30.0)
    assertEqual(valid.temperatureProfiles.Spring.warmTargetF, 70.0)

    local invalid = ChangingSkies.Settings.readFromTable({
        SpringColdTargetF = 40.0,
        AddedWeatherFrequency = 8,
        AddedWeatherSeverity = -1,
        StormFrequency = 99,
        StormType = 99,
        StormLength = 99,
        AddedThunderFrequency = 99,
        AddedThunderScope = 99,
        CooldownMinimumHours = 10.0,
        CooldownMaximumHours = 2.0,
    })
    assertEqual(invalid.temperatureProfiles.Spring.coldTargetF, 30.0)
    assertEqual(invalid.temperatureProfiles.Spring.warmTargetF, 70.0)
    assertEqual(invalid.frequency, ChangingSkies.Constants.DEFAULTS.frequency)
    assertEqual(invalid.severity, ChangingSkies.Constants.DEFAULTS.severity)
    assertEqual(invalid.stormFrequency, ChangingSkies.Constants.DEFAULTS.stormFrequency)
    assertEqual(invalid.stormType, ChangingSkies.Constants.DEFAULTS.stormType)
    assertEqual(invalid.stormLength, ChangingSkies.Constants.DEFAULTS.stormLength)
    assertEqual(invalid.addedThunderFrequency,
        ChangingSkies.Constants.DEFAULTS.addedThunderFrequency)
    assertEqual(invalid.addedThunderScope,
        ChangingSkies.Constants.DEFAULTS.addedThunderScope)
    assertEqual(invalid.cooldownMinimumHours,
        ChangingSkies.Constants.DEFAULTS.cooldownMinimumHours)

    local reversed = ChangingSkies.Settings.readFromTable({
        SpringColdTargetF = 80.0,
        SpringWarmTargetF = 20.0,
    })
    assertEqual(reversed.temperatureProfiles.Spring.coldTargetF, 30.0)
    assertEqual(reversed.temperatureProfiles.Spring.warmTargetF, 70.0)

end)

test("invalid numeric endpoints fall back to rounded defaults before any valid pair", function()
    local invalidPairs = {
        { cold = nil, warm = 10.0 },
        { cold = 10.0, warm = nil },
        { cold = "not numeric", warm = 10.0 },
        { cold = 0 / 0, warm = 10.0 },
        { cold = -math.huge, warm = 10.0 },
        { cold = -151.0, warm = 0.0 },
        { cold = 0.0, warm = 201.0 },
        { cold = 20.0, warm = 10.0 },
    }
    for _, values in ipairs(invalidPairs) do
        ChangingSkies.Settings.resetValidationMemoryForTests()
        local settings = ChangingSkies.Settings.readFromTable({
            SpringColdTargetF = values.cold,
            SpringWarmTargetF = values.warm,
        })
        assertEqual(settings.temperatureProfiles.Spring.coldTargetF, 37.0)
        assertEqual(settings.temperatureProfiles.Spring.warmTargetF, 66.0)
    end
end)

test("Fahrenheit delta and air-mass interpolation", function()
    assertNear(ChangingSkies.Temperature.calculateDeltaC(-18.0, 18.0, -1.0), -10.0, 0.0001)
    assertNear(ChangingSkies.Temperature.calculateDeltaC(-18.0, 18.0, 0.0), 0.0, 0.0001)
    assertNear(ChangingSkies.Temperature.calculateDeltaC(-18.0, 18.0, 1.0), 10.0, 0.0001)
end)

test("active weather target composition preserves interpolation", function()
    ChangingSkies.Temperature.resetOwnershipForTests()
    local manager, temperatureFloat, snowBool = newTemperatureManager({
        vanillaTemperature = 10.0,
        airMass = 0.0,
        weatherRunning = true,
        overrideEnabled = true,
        override = 0.0,
        overrideInterpolation = 0.25,
    })
    local result = ChangingSkies.Temperature.apply(manager, temperatureSettings(18.0, 18.0))
    assertNear(result.deltaC, 10.0, 0.0001)
    assertNear(temperatureFloat.moddedValue, 20.0, 0.0001)
    assertNear(temperatureFloat.override, 10.0, 0.0001)
    assertNear(temperatureFloat.overrideInterpolation, 0.25, 0.0001)
    assertNear(result.correctedTemperature, 17.5, 0.0001)
    assertEqual(snowBool.moddedValue, false)
end)

test("temperature bounds and corrected snow boolean", function()
    ChangingSkies.Temperature.resetOwnershipForTests()
    local hotManager, hotFloat = newTemperatureManager({
        vanillaTemperature = 90.0,
        airMass = 0.0,
    })
    ChangingSkies.Temperature.apply(hotManager, temperatureSettings(18.0, 18.0))
    assertNear(hotFloat.moddedValue, (200.0 - 32.0) * (5.0 / 9.0), 0.000000001)

    local coldManager, coldFloat, snowBool = newTemperatureManager({
        vanillaTemperature = -100.0,
        airMass = 0.0,
    })
    ChangingSkies.Temperature.apply(coldManager, temperatureSettings(-18.0, -18.0))
    assertNear(coldFloat.moddedValue, (-150.0 - 32.0) * (5.0 / 9.0), 0.000000001)
    assertNear(ChangingSkies.Constants.TEMPERATURE_MIN_C,
        (-150.0 - 32.0) * (5.0 / 9.0), 0.000000001)
    assertNear(ChangingSkies.Constants.TEMPERATURE_MAX_C,
        (200.0 - 32.0) * (5.0 / 9.0), 0.000000001)
    assertEqual(snowBool.enableModded, true)
    assertEqual(snowBool.moddedValue, true)
end)

test("admin override relinquishes only owned values", function()
    ChangingSkies.Temperature.resetOwnershipForTests()
    local manager, temperatureFloat, snowBool = newTemperatureManager({
        vanillaTemperature = 5.0,
    })
    ChangingSkies.Temperature.apply(manager, temperatureSettings(-18.0, -18.0))
    assertEqual(temperatureFloat.enableModded, true)
    assertEqual(snowBool.enableModded, true)
    temperatureFloat.enableAdmin = true
    local result = ChangingSkies.Temperature.apply(manager, temperatureSettings(-18.0, -18.0))
    assertEqual(result.reason, "admin")
    assertEqual(temperatureFloat.enableModded, false)
    assertEqual(snowBool.enableModded, false)
end)

test("Insane frequency triggers on the first eligible roll", function()
    local probabilities = ChangingSkies.Constants.WEATHER_PROBABILITIES
    assertEqual(#probabilities, 6)
    assertEqual(ChangingSkies.Constants.DEFAULTS.frequency, 1)
    assertNear(probabilities[1], 1.0 / (144.0 * 14.0), 0.000000001)
    assertNear(probabilities[2], 1.0 / (144.0 * 10.0), 0.000000001)
    assertNear(probabilities[3], 1.0 / (144.0 * 7.0), 0.000000001)
    assertNear(probabilities[4], 1.0 / (144.0 * 4.0), 0.000000001)
    assertNear(probabilities[5], 1.0 / (144.0 * 2.0), 0.000000001)
    assertEqual(probabilities[6], 1.0)

    local settings = weatherSettings()
    settings.weatherProbability = probabilities[6]
    local manager = newWeatherManager(false, true)
    local state = { lastWeatherRunning = false }
    local result = ChangingSkies.Weather.onTenMinutes(
        manager,
        settings,
        state,
        90.0,
        function() return 0.999999 end
    )
    assertEqual(result, "TRIGGERED")
    assertEqual(manager.triggerCount, 1)
end)

test("storm and thunder constants preserve exact meanings", function()
    local weather = ChangingSkies.Constants.WEATHER_PROBABILITIES
    local storm = ChangingSkies.Constants.STORM_PROBABILITIES
    assertEqual(#storm, 7)
    assertEqual(storm[1], 0.0)
    for index = 1, #weather do
        assertNear(storm[index + 1], weather[index], 0.000000001)
    end
    assertEqual(storm[7], 1.0)

    local severity = ChangingSkies.Constants.SEVERITY_BANDS
    local expectedSeverity = {
        0.10, 0.25, 0.26, 0.40, 0.41, 0.55,
        0.56, 0.75, 0.76, 0.90, 0.91, 1.00,
    }
    for index = 1, 6 do
        assertNear(severity[index].minimum, expectedSeverity[index * 2 - 1], 0.000000001)
        assertNear(severity[index].maximum, expectedSeverity[index * 2], 0.000000001)
    end

    local stages = ChangingSkies.Constants.STORM_STAGE_BY_TYPE
    assertEqual(stages[2], 2)
    assertEqual(stages[3], 8)
    assertEqual(stages[4], 7)
    local seasonalStages = ChangingSkies.Constants.SEASONAL_STORM_STAGE_BY_EROSION_SEASON
    assertEqual(seasonalStages[1], 3)
    assertEqual(seasonalStages[2], 8)
    assertEqual(seasonalStages[3], 8)
    assertEqual(seasonalStages[4], 3)
    assertEqual(seasonalStages[5], 7)
    local durations = ChangingSkies.Constants.STORM_DURATION_BANDS
    local expectedDurations = { 6.0, 12.0, 12.0, 24.0, 24.0, 48.0, 48.0, 96.0 }
    for index = 1, 4 do
        assertEqual(durations[index].minimum, expectedDurations[index * 2 - 1])
        assertEqual(durations[index].maximum, expectedDurations[index * 2])
    end
    assertEqual(ChangingSkies.Constants.RANDOM_STORM_DURATION_MINIMUM, 4)
    assertEqual(ChangingSkies.Constants.RANDOM_STORM_DURATION_MAXIMUM, 240)

    local thunder = ChangingSkies.Constants.THUNDER_PROBABILITIES
    assertEqual(#thunder, 5)
    assertEqual(thunder[1], 0.0)
    assertNear(thunder[2], 1.0 / 120.0, 0.000000001)
    assertNear(thunder[3], 1.0 / 30.0, 0.000000001)
    assertNear(thunder[4], 1.0 / 10.0, 0.000000001)
    assertEqual(thunder[5], 1.0)
    assertEqual(ChangingSkies.Constants.THUNDER_MINIMUM_INTERVAL_MINUTES, 5)
end)

test("Seasonal maps every ErosionSeason and fallback to one exact stage", function()
    local cases = {
        { season = 1, expected = 3 },
        { season = 2, expected = 8 },
        { season = 3, expected = 8 },
        { season = 4, expected = 3 },
        { season = 5, expected = 7 },
        { season = 99, expected = 3 },
        { unavailable = true, expected = 3 },
    }
    for index, item in ipairs(cases) do
        local settings = weatherSettings()
        settings.stormProbability = 1.0
        settings.stormType = 1
        local manager = newWeatherManager(false, true, {
            erosionSeasonId = item.season,
            seasonUnavailable = item.unavailable,
        })
        local state = { lastWeatherRunning = false }
        local result = ChangingSkies.Weather.onTenMinutes(
            manager, settings, state, 705.0 + index,
            sequenceRandom({ 0.0, 0.5 })
        )
        assertEqual(result, "STORM_TRIGGERED")
        assertEqual(manager.lastStageId, item.expected)
        assertEqual(manager.stageTriggerCount, 1)
        assertEqual(manager.triggerCount, 0)
        assertEqual(state.schedulerStatus, "ACTIVE")
    end
end)

test("storm types and duration bands trigger exact vanilla stages", function()
    local expectedStages = { 2, 8, 7 }
    for offset = 1, 3 do
        local stormType = offset + 1
        local settings = weatherSettings()
        settings.enableAddedWeather = false
        settings.stormProbability = 1.0
        settings.stormType = stormType
        settings.stormDurationBand = ChangingSkies.Constants.STORM_DURATION_BANDS[offset]
        local manager = newWeatherManager(false, true)
        local result = ChangingSkies.Weather.onTenMinutes(
            manager,
            settings,
            { lastWeatherRunning = false },
            700.0 + stormType,
            sequenceRandom({ 0.0, 0.5 })
        )
        assertEqual(result, "STORM_TRIGGERED")
        assertEqual(manager.lastStageId, expectedStages[offset])
        local band = settings.stormDurationBand
        assertNear(manager.lastStageDurationHours,
            (band.minimum + band.maximum) / 2.0 - 2.0, 0.0001)
        assertEqual(manager.triggerCount, 0)
    end
end)

test("Random uniformly selects from the three exact stages", function()
    local selected = {}
    for randomChoice = 0, 2 do
        local settings = weatherSettings()
        settings.enableAddedWeather = false
        settings.stormProbability = 1.0
        settings.stormType = 5
        settings.stormDurationBand = { minimum = 48.0, maximum = 96.0 }
        local manager = newWeatherManager(false, true)
        local result = ChangingSkies.Weather.onTenMinutes(
            manager,
            settings,
            { lastWeatherRunning = false },
            710.0 + randomChoice,
            sequenceRandom({ 0.0, (randomChoice + 0.1) / 3.0, 0.25 })
        )
        assertEqual(result, "STORM_TRIGGERED")
        selected[randomChoice + 1] = manager.lastStageId
        assertNear(manager.lastStageDurationHours, 58.0, 0.0001)
    end
    assertEqual(selected[1], 2)
    assertEqual(selected[2], 8)
    assertEqual(selected[3], 7)
end)

test("Random stage selection clamps invalid authority RNG", function()
    local cases = {
        { unit = -1.0, expected = 2 },
        { unit = 2.0, expected = 7 },
        { unit = 0 / 0, expected = 2 },
        { unit = math.huge, expected = 2 },
        { unit = -math.huge, expected = 2 },
    }
    for index, item in ipairs(cases) do
        local settings = weatherSettings()
        settings.enableAddedWeather = false
        settings.stormProbability = 1.0
        settings.stormType = 5
        local manager = newWeatherManager(false, true)
        assertEqual(ChangingSkies.Weather.onTenMinutes(
            manager, settings, { lastWeatherRunning = false }, 712.0 + index,
            sequenceRandom({ 0.0, item.unit, 0.5 })
        ), "STORM_TRIGGERED")
        assertEqual(manager.lastStageId, item.expected)
    end
end)

test("retired Added Thunder frequency values fall back to Off", function()
    for _, retiredValue in ipairs({ 6, 7 }) do
        local settings = ChangingSkies.Settings.readFromTable({
            AddedThunderFrequency = retiredValue,
        })
        assertEqual(settings.addedThunderFrequency, 1)
        assertEqual(settings.addedThunderProbability, 0.0)
    end
end)

test("random nominal storm totals map from 4 through 240 to middle stages 2 through 238", function()
    local cases = {
        { unit = 0.0, expected = 2 },
        { unit = 0.5, expected = 120 },
        { unit = 1.0, expected = 238 },
        { unit = 2.0, expected = 238 },
        { unit = -1.0, expected = 2 },
        { unit = 0 / 0, expected = 2 },
    }
    for index, item in ipairs(cases) do
        local settings = weatherSettings()
        settings.enableAddedWeather = false
        settings.stormProbability = 1.0
        settings.stormType = 2
        settings.stormLength = 5
        settings.stormDurationBand = nil
        local values = { 0.0 }
        values[#values + 1] = item.unit
        local manager = newWeatherManager(false, true)
        local result = ChangingSkies.Weather.onTenMinutes(
            manager,
            settings,
            { lastWeatherRunning = false },
            715.0 + index,
            sequenceRandom(values)
        )
        assertEqual(result, "STORM_TRIGGERED")
        assertEqual(manager.lastStageDurationHours, item.expected)
        assertEqual(manager.lastStageDurationHours,
            math.floor(manager.lastStageDurationHours))
        assertEqual(manager.lastStageDurationHours >= 2 and
            manager.lastStageDurationHours <= 238, true)
    end
end)

test("storm rolls first and ordinary weather is the fallback", function()
    local prioritySettings = weatherSettings()
    prioritySettings.stormProbability = 1.0
    prioritySettings.stormType = 1
    local priorityManager = newWeatherManager(false, true)
    local priority = ChangingSkies.Weather.onTenMinutes(
        priorityManager,
        prioritySettings,
        { lastWeatherRunning = false },
        720.0,
        sequenceRandom({ 0.999999, 0.5 })
    )
    assertEqual(priority, "STORM_TRIGGERED")
    assertEqual(priorityManager.stageTriggerCount, 1)
    assertEqual(priorityManager.triggerCount, 0)

    local fallbackSettings = weatherSettings()
    fallbackSettings.stormProbability = 0.5
    local fallbackManager = newWeatherManager(false, true)
    local fallback = ChangingSkies.Weather.onTenMinutes(
        fallbackManager,
        fallbackSettings,
        { lastWeatherRunning = false },
        721.0,
        sequenceRandom({ 0.75, 0.0, 0.5, 0.25 })
    )
    assertEqual(fallback, "TRIGGERED")
    assertEqual(fallbackManager.stageTriggerCount, 0)
    assertEqual(fallbackManager.triggerCount, 1)
end)

test("storm-only scheduling, both-disabled state, and rejection recovery", function()
    local stormOnly = weatherSettings()
    stormOnly.enableAddedWeather = false
    stormOnly.stormProbability = 1.0
    local activeManager = newWeatherManager(false, true)
    assertEqual(ChangingSkies.Weather.reconcile(
        activeManager, stormOnly, { lastWeatherRunning = false }, 730.0,
        function() return 0.0 end
    ), "ELIGIBLE")

    local runningManager = newWeatherManager(true, true)
    assertEqual(ChangingSkies.Weather.onTenMinutes(
        runningManager, stormOnly, { lastWeatherRunning = false }, 730.1,
        function() return 0.0 end
    ), "ACTIVE")
    assertEqual(runningManager.stageTriggerCount, 0)

    local cooldownState = { lastWeatherRunning = true }
    assertEqual(ChangingSkies.Weather.reconcile(
        activeManager, stormOnly, cooldownState, 730.2,
        function() return 0.5 end
    ), "COOLDOWN")
    assertNear(cooldownState.cooldownUntilWorldAgeHours, 733.2, 0.0001)

    local disabled = weatherSettings()
    disabled.enableAddedWeather = false
    disabled.stormProbability = 0.0
    assertEqual(ChangingSkies.Weather.reconcile(
        activeManager, disabled, { lastWeatherRunning = false }, 731.0,
        function() return 0.0 end
    ), "DISABLED")

    local rejectedManager = newWeatherManager(false, false)
    local rejectedState = { lastWeatherRunning = false }
    local rejected = ChangingSkies.Weather.onTenMinutes(
        rejectedManager,
        stormOnly,
        rejectedState,
        732.0,
        sequenceRandom({ 0.0, 0.5 })
    )
    assertEqual(rejected, "TRIGGER_REJECTED")
    assertEqual(rejectedState.schedulerStatus, "ELIGIBLE")
    assertEqual(rejectedManager.triggerCount, 0)
end)

test("same-slot scheduler deduplication and verified trigger", function()
    local manager = newWeatherManager(false, true)
    local state = { lastWeatherRunning = false }
    local result = ChangingSkies.Weather.onTenMinutes(
        manager, weatherSettings(), state, 100.0, function() return 0.0 end
    )
    assertEqual(result, "TRIGGERED")
    assertEqual(manager.triggerCount, 1)
    assertEqual(state.schedulerStatus, "ACTIVE")
    local duplicate = ChangingSkies.Weather.onTenMinutes(
        manager, weatherSettings(), state, 100.0, function() return 0.0 end
    )
    assertEqual(duplicate, "DUPLICATE")
    assertEqual(manager.triggerCount, 1)
end)

test("scheduler never overlaps active weather", function()
    local manager = newWeatherManager(true, true)
    local state = { lastWeatherRunning = false }
    local result = ChangingSkies.Weather.onTenMinutes(
        manager, weatherSettings(), state, 200.0, function() return 0.0 end
    )
    assertEqual(result, "ACTIVE")
    assertEqual(manager.triggerCount, 0)
end)

test("scheduler rejects an unverified trigger", function()
    local manager = newWeatherManager(false, false)
    local state = { lastWeatherRunning = false }
    local result = ChangingSkies.Weather.onTenMinutes(
        manager, weatherSettings(), state, 300.0, function() return 0.0 end
    )
    assertEqual(result, "TRIGGER_REJECTED")
    assertEqual(state.schedulerStatus, "ELIGIBLE")
end)

test("weather completion starts a fresh absolute cooldown", function()
    local manager = newWeatherManager(false, false)
    local state = { lastWeatherRunning = true }
    local result = ChangingSkies.Weather.reconcile(
        manager, weatherSettings(), state, 50.0, function() return 0.5 end
    )
    assertEqual(result, "COOLDOWN")
    assertNear(state.cooldownUntilWorldAgeHours, 53.0, 0.0001)
    assertEqual(state.lastWeatherRunning, false)
end)

test("added thunder handles off, no weather, failed roll, no player, and missing system", function()
    local restorePlayers = installPlayerEnvironment(false, { count = 0 })
    local activeManager = newThunderManager(true, true)
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        activeManager,
        { addedThunderProbability = 0.0 },
        {},
        800.0,
        function() return 0.0 end
    ), "DISABLED")

    local quietManager = newThunderManager(false, true)
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        quietManager,
        { addedThunderProbability = 1.0 },
        {},
        801.0,
        function() return 0.0 end
    ), "NO_WEATHER")

    assertEqual(ChangingSkies.Thunder.onClimateTick(
        activeManager,
        { addedThunderProbability = 0.5 },
        {},
        802.0,
        function() return 0.75 end
    ), "ROLL_FAILED")

    local noSystemManager = newThunderManager(true, false)
    local noSystemState = {}
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        noSystemManager,
        { addedThunderProbability = 1.0 },
        noSystemState,
        803.0,
        function() return 0.0 end
    ), "MISSING_SYSTEM")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        noSystemManager,
        { addedThunderProbability = 1.0 },
        noSystemState,
        803.0,
        function() return 0.0 end
    ), "DUPLICATE")

    local noPlayerState = {}
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        activeManager,
        { addedThunderProbability = 1.0 },
        noPlayerState,
        804.0,
        function() return 0.0 end
    ), "NO_PLAYER")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        activeManager,
        { addedThunderProbability = 1.0 },
        noPlayerState,
        804.0,
        function() return 0.0 end
    ), "DUPLICATE")
    restorePlayers()
end)

test("Added Thunder scope uses only the active stage or vanilla storm state", function()
    local restorePlayers = installPlayerEnvironment(false, { newPlayer(100.0, 200.0) })
    local stormStageIds = { 2, 3, 7, 8 }
    for index, stageId in ipairs(stormStageIds) do
        local manager = newThunderManager(true, true, { currentStageId = stageId })
        assertEqual(ChangingSkies.Thunder.onClimateTick(
            manager,
            { addedThunderProbability = 1.0, addedThunderScope = 2 },
            {},
            805.0 + index,
            sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
        ), "TRIGGERED")
    end

    local quietStage = newThunderManager(true, true, { currentStageId = 1 })
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        quietStage,
        { addedThunderProbability = 1.0, addedThunderScope = 2 },
        {},
        806.0,
        function() return 0.0 end
    ), "OUT_OF_SCOPE")

    local vanillaQuiet = newThunderManager(true, true, {
        currentStageId = 3,
        thunderStorm = false,
        tropicalStorm = false,
    })
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        vanillaQuiet,
        { addedThunderProbability = 1.0, addedThunderScope = 3 },
        {},
        807.0,
        function() return 0.0 end
    ), "OUT_OF_SCOPE")

    local vanillaThunder = newThunderManager(true, true, { thunderStorm = true })
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        vanillaThunder,
        { addedThunderProbability = 1.0, addedThunderScope = 3 },
        {},
        808.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")

    local tropical = newThunderManager(true, true, { tropicalStorm = true })
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        tropical,
        { addedThunderProbability = 1.0, addedThunderScope = 3 },
        {},
        809.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")

    local allWeather = newThunderManager(true, true, { currentStageId = 1 })
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        allWeather,
        { addedThunderProbability = 1.0, addedThunderScope = 1 },
        {},
        810.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")
    restorePlayers()
end)

test("successful Added Thunder is throttled to one event every five active-weather minutes", function()
    local restorePlayers = installPlayerEnvironment(false, { newPlayer(100.0, 200.0) })
    local manager, events = newThunderManager(true, true)
    local settings = {
        enableAddedWeather = false,
        stormProbability = 0.0,
        addedThunderProbability = 1.0,
    }
    local state = { currentWeatherCreatedByChangingSkies = false }
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, settings, state, 810.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, settings, state, 810.005,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "DUPLICATE")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, settings, state, 810.02,
        function() error("throttled minute must not roll") end
    ), "THROTTLED")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, settings, state, (48600 + 5) / 60.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, settings, state, 900.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")
    assertEqual(#events, 3)
    restorePlayers()
end)

test("SP added thunder uses valid slots, bounded integer coordinates, and sound-only flags", function()
    local players = { nil, newPlayer(100.0, 200.0), count = 2 }
    local restorePlayers = installPlayerEnvironment(false, players)
    local manager, events = newThunderManager(true, true)
    local result, x, y = ChangingSkies.Thunder.onClimateTick(
        manager,
        { addedThunderProbability = 1.0 },
        {},
        910.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    )
    restorePlayers()
    assertEqual(result, "TRIGGERED")
    assertEqual(#events, 1)
    assertEqual(x, math.floor(x))
    assertEqual(y, math.floor(y))
    local distance = math.sqrt((x - 100.0) ^ 2 + (y - 200.0) ^ 2)
    assertEqual(distance >= 249.0 and distance <= 901.0, true)
    assertEqual(events[1].sound, true)
    assertEqual(events[1].lightning, false)
    assertEqual(events[1].rumble, false)
end)

test("server added thunder selects one online player for one global event", function()
    local first = newPlayer(0.0, 0.0)
    local second = newPlayer(1000.0, 2000.0)
    local restorePlayers = installPlayerEnvironment(true, { first, second })
    local manager, events = newThunderManager(true, true)
    local result, x, y = ChangingSkies.Thunder.onClimateTick(
        manager,
        { addedThunderProbability = 1.0 },
        {},
        920.0,
        sequenceRandom({ 0.0, 0.75, 0.25, 0.999999 })
    )
    restorePlayers()
    assertEqual(result, "TRIGGERED")
    assertEqual(#events, 1)
    local distanceFromSecond = math.sqrt((x - 1000.0) ^ 2 + (y - 2000.0) ^ 2)
    assertEqual(distanceFromSecond >= 899.0 and distanceFromSecond <= 901.0, true)
end)

test("state is namespaced, schema-versioned, and corruption-safe", function()
    local manager = { modData = { ChangingSkies = "corrupt" } }
    function manager:getModData() return self.modData end
    local state = ChangingSkies.State.ensure(manager)
    assertEqual(state.schemaVersion, ChangingSkies.Constants.SCHEMA_VERSION)
    assertEqual(state.currentWeatherCreatedByChangingSkies, false)
    assertEqual(state.lastProcessedThunderMinuteSlot, nil)
    assertEqual(state.lastTriggeredThunderMinuteSlot, nil)
    assertEqual(manager.modData.ChangingSkies, state)
end)

test("corrupt persisted thunder-minute slots repair in place", function()
    local persistedState = {
        schemaVersion = ChangingSkies.Constants.SCHEMA_VERSION,
        schedulerStatus = "ELIGIBLE",
        lastWeatherRunning = false,
        currentWeatherCreatedByChangingSkies = false,
        lastProcessedThunderMinuteSlot = "corrupt",
        lastTriggeredThunderMinuteSlot = "corrupt",
        unrelated = "preserved",
    }
    local manager = { modData = { ChangingSkies = persistedState } }
    function manager:getModData() return self.modData end
    local repaired = ChangingSkies.State.ensure(manager)
    assertEqual(repaired, persistedState)
    assertEqual(repaired.lastProcessedThunderMinuteSlot, nil)
    assertEqual(repaired.lastTriggeredThunderMinuteSlot, nil)
    assertEqual(repaired.unrelated, "preserved")

    repaired.lastProcessedThunderMinuteSlot = 1.5
    assertEqual(ChangingSkies.State.ensure(manager).lastProcessedThunderMinuteSlot, nil)
    repaired.lastProcessedThunderMinuteSlot = math.huge
    assertEqual(ChangingSkies.State.ensure(manager).lastProcessedThunderMinuteSlot, nil)
    repaired.lastProcessedThunderMinuteSlot = 1234
    assertEqual(ChangingSkies.State.ensure(manager).lastProcessedThunderMinuteSlot, 1234)
    repaired.lastTriggeredThunderMinuteSlot = 1.5
    assertEqual(ChangingSkies.State.ensure(manager).lastTriggeredThunderMinuteSlot, nil)
    repaired.lastTriggeredThunderMinuteSlot = math.huge
    assertEqual(ChangingSkies.State.ensure(manager).lastTriggeredThunderMinuteSlot, nil)
    repaired.lastTriggeredThunderMinuteSlot = 1230
    assertEqual(ChangingSkies.State.ensure(manager).lastTriggeredThunderMinuteSlot, 1230)
end)

test("persisted thunder slots prevent reload duplicates and catch-up", function()
    local restorePlayers = installPlayerEnvironment(false, { newPlayer(0.0, 0.0) })
    local manager, events = newThunderManager(true, true)
    local state = {
        lastProcessedThunderMinuteSlot = 6000,
        lastTriggeredThunderMinuteSlot = 6000,
    }
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, { addedThunderProbability = 1.0 }, state, 100.0,
        function() error("reload duplicate must not roll") end
    ), "DUPLICATE")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, { addedThunderProbability = 1.0 }, state, (6000 + 1) / 60.0,
        function() error("reload throttle must not roll") end
    ), "THROTTLED")
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, { addedThunderProbability = 1.0 }, state, (6000 + 5) / 60.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")
    state.lastTriggeredThunderMinuteSlot = 7000
    assertEqual(ChangingSkies.Thunder.onClimateTick(
        manager, { addedThunderProbability = 1.0 }, state, (6000 + 6) / 60.0,
        sequenceRandom({ 0.0, 0.0, 0.0, 0.0 })
    ), "TRIGGERED")
    assertEqual(state.lastTriggeredThunderMinuteSlot, 6006)
    assertEqual(#events, 2)
    restorePlayers()
end)

test("weather ownership marker distinguishes verified and natural periods", function()
    local triggeredManager = newWeatherManager(false, true)
    local triggeredState = {
        lastWeatherRunning = false,
        currentWeatherCreatedByChangingSkies = false,
    }
    local triggered = ChangingSkies.Weather.onTenMinutes(
        triggeredManager,
        weatherSettings(),
        triggeredState,
        400.0,
        function() return 0.0 end
    )
    assertEqual(triggered, "TRIGGERED")
    assertEqual(triggeredState.currentWeatherCreatedByChangingSkies, true)

    ChangingSkies.Weather.reconcile(
        triggeredManager,
        weatherSettings(),
        triggeredState,
        400.1,
        function() return 0.0 end
    )
    assertEqual(triggeredState.currentWeatherCreatedByChangingSkies, true)

    local naturalManager = newWeatherManager(true, false)
    local naturalState = {
        lastWeatherRunning = false,
        currentWeatherCreatedByChangingSkies = true,
    }
    ChangingSkies.Weather.reconcile(
        naturalManager,
        weatherSettings(),
        naturalState,
        500.0,
        function() return 0.0 end
    )
    assertEqual(naturalState.currentWeatherCreatedByChangingSkies, false)
end)

test("weather ownership marker clears on completion and repairs corruption", function()
    local manager = newWeatherManager(false, false)
    local state = {
        lastWeatherRunning = true,
        currentWeatherCreatedByChangingSkies = true,
    }
    ChangingSkies.Weather.reconcile(
        manager,
        weatherSettings(),
        state,
        600.0,
        function() return 0.0 end
    )
    assertEqual(state.currentWeatherCreatedByChangingSkies, false)

    local persistedManager = {
        modData = {
            ChangingSkies = {
                schemaVersion = ChangingSkies.Constants.SCHEMA_VERSION,
                schedulerStatus = "ACTIVE",
                lastWeatherRunning = true,
                currentWeatherCreatedByChangingSkies = "corrupt",
            },
        },
    }
    function persistedManager:getModData() return self.modData end
    local repaired = ChangingSkies.State.ensure(persistedManager)
    assertEqual(repaired.currentWeatherCreatedByChangingSkies, false)
end)

print("All " .. tostring(testsRun) .. " Changing Skies tests passed.")
