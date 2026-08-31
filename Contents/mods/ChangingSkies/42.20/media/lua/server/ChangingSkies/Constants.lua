ChangingSkies = ChangingSkies or {}

local Constants = {}

Constants.SCHEMA_VERSION = 1
Constants.TEMPERATURE_MIN_C = -101.11111111111111
Constants.TEMPERATURE_MAX_C = 93.33333333333333
Constants.NOMINAL_AIR_MASS_SPREAD_C = 16.0
Constants.RANDOM_SCALE = 1000000

Constants.DEFAULTS = {
    enableAddedWeather = true,
    frequency = 1,
    severity = 3,
    stormFrequency = 1,
    stormType = 1,
    stormLength = 2,
    addedThunderFrequency = 1,
    cooldownMinimumHours = 24.0,
    cooldownMaximumHours = 72.0,
    enableTemperatureAdjustment = false,
    debugLogging = false,
}

-- Per eligible ten-minute check; expected waits exclude cooldown and vanilla weather.
Constants.WEATHER_PROBABILITIES = {
    1.0 / (144.0 * 14.0),
    1.0 / (144.0 * 10.0),
    1.0 / (144.0 * 7.0),
    1.0 / (144.0 * 4.0),
    1.0 / (144.0 * 2.0),
    1.0,
}

Constants.SEVERITY_BANDS = {
    { minimum = 0.10, maximum = 0.25 },
    { minimum = 0.26, maximum = 0.40 },
    { minimum = 0.41, maximum = 0.55 },
    { minimum = 0.56, maximum = 0.75 },
    { minimum = 0.76, maximum = 0.90 },
    { minimum = 0.91, maximum = 1.00 },
}

Constants.STORM_PROBABILITIES = {
    0.0,
    1.0 / (144.0 * 14.0),
    1.0 / (144.0 * 10.0),
    1.0 / (144.0 * 7.0),
    1.0 / (144.0 * 4.0),
    1.0 / (144.0 * 2.0),
    1.0,
}

Constants.STORM_STAGE_BY_TYPE = {
    2,
    8,
    7,
}

Constants.STORM_DURATION_BANDS = {
    { minimum = 6.0, maximum = 12.0 },
    { minimum = 12.0, maximum = 24.0 },
    { minimum = 24.0, maximum = 48.0 },
    { minimum = 48.0, maximum = 96.0 },
}

Constants.THUNDER_PROBABILITIES = {
    0.0,
    1.0 / 120.0,
    1.0 / 60.0,
    1.0 / 30.0,
    1.0 / 15.0,
    1.0 / 5.0,
    1.0,
}

Constants.THUNDER_MINIMUM_DISTANCE = 250.0
Constants.THUNDER_MAXIMUM_DISTANCE = 900.0

Constants.SEASON_TEMPERATURE_REFERENCES_F = {
    Spring = { coldF = 37.5, warmF = 66.3 },
    Summer = { coldF = 60.2, warmF = 89.0 },
    Fall = { coldF = 42.4, warmF = 71.2 },
    Winter = { coldF = 19.9, warmF = 48.7 },
}

-- GameTime months are zero-based: January is 0 and December is 11.
Constants.SEASON_PROFILE_BY_MONTH = {
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

ChangingSkies.Constants = Constants
