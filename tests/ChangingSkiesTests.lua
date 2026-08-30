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

local function temperatureSettings(coldF, warmF)
    local pair = { coldF = coldF, warmF = warmF }
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
    function manager:getSeasonId() return options.seasonId or 1 end
    function manager:getClimateValuesCopy() return clean end
    function manager:getWeatherPeriod() return weatherPeriod end
    return manager, temperatureFloat, snowBool
end

local function weatherSettings()
    return {
        enableAddedWeather = true,
        weatherProbability = 1.0,
        severityBand = { minimum = 0.41, maximum = 0.55 },
        cooldownMinimumHours = 2.0,
        cooldownMaximumHours = 4.0,
    }
end

local function newWeatherManager(initiallyRunning, startsWhenTriggered)
    local period = { running = initiallyRunning == true }
    function period:isRunning() return self.running end
    local manager = { triggerCount = 0 }
    function manager:getWeatherPeriod() return period end
    function manager:triggerCustomWeather(_, _)
        self.triggerCount = self.triggerCount + 1
        if startsWhenTriggered then
            period.running = true
        end
        return true
    end
    return manager, period
end

test("settings validation preserves last valid endpoints", function()
    ChangingSkies.Settings.resetValidationMemoryForTests()
    local valid = ChangingSkies.Settings.readFromTable({
        SpringColdEndAdjustmentF = -10.0,
        SpringWarmEndAdjustmentF = 10.0,
    })
    assertEqual(valid.temperatureProfiles.Spring.coldF, -10.0)
    assertEqual(valid.temperatureProfiles.Spring.warmF, 10.0)

    local invalid = ChangingSkies.Settings.readFromTable({
        SpringColdEndAdjustmentF = 100.0,
        SpringWarmEndAdjustmentF = -100.0,
        AddedWeatherFrequency = 999,
        AddedWeatherSeverity = -1,
        CooldownMinimumHours = 10.0,
        CooldownMaximumHours = 2.0,
    })
    assertEqual(invalid.temperatureProfiles.Spring.coldF, -10.0)
    assertEqual(invalid.temperatureProfiles.Spring.warmF, 10.0)
    assertEqual(invalid.frequency, ChangingSkies.Constants.DEFAULTS.frequency)
    assertEqual(invalid.severity, ChangingSkies.Constants.DEFAULTS.severity)
    assertEqual(invalid.cooldownMinimumHours,
        ChangingSkies.Constants.DEFAULTS.cooldownMinimumHours)

    ChangingSkies.Settings.resetValidationMemoryForTests()
    local noPrevious = ChangingSkies.Settings.readFromTable({
        SpringColdEndAdjustmentF = 100.0,
        SpringWarmEndAdjustmentF = -100.0,
    })
    assertEqual(noPrevious.temperatureProfiles.Spring.coldF, 0.0)
    assertEqual(noPrevious.temperatureProfiles.Spring.warmF, 0.0)
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
        vanillaTemperature = 79.0,
        airMass = 0.0,
    })
    ChangingSkies.Temperature.apply(hotManager, temperatureSettings(18.0, 18.0))
    assertEqual(hotFloat.moddedValue, 80.0)

    local coldManager, _, snowBool = newTemperatureManager({
        vanillaTemperature = 5.0,
        airMass = 0.0,
    })
    ChangingSkies.Temperature.apply(coldManager, temperatureSettings(-18.0, -18.0))
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

test("state is namespaced, schema-versioned, and corruption-safe", function()
    local manager = { modData = { ChangingSkies = "corrupt" } }
    function manager:getModData() return self.modData end
    local state = ChangingSkies.State.ensure(manager)
    assertEqual(state.schemaVersion, ChangingSkies.Constants.SCHEMA_VERSION)
    assertEqual(state.currentWeatherCreatedByChangingSkies, false)
    assertEqual(manager.modData.ChangingSkies, state)
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
