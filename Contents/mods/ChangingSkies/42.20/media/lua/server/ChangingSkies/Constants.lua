ChangingSkies = ChangingSkies or {}

local Constants = {}

Constants.SCHEMA_VERSION = 1
Constants.TEMPERATURE_MIN_C = -80.0
Constants.TEMPERATURE_MAX_C = 80.0
Constants.NOMINAL_AIR_MASS_SPREAD_C = 16.0
Constants.RANDOM_SCALE = 1000000

Constants.DEFAULTS = {
    enableAddedWeather = true,
    frequency = 3,
    severity = 3,
    cooldownMinimumHours = 24.0,
    cooldownMaximumHours = 72.0,
    enableTemperatureAdjustment = false,
    debugLogging = false,
}

-- Per eligible ten-minute check; expected waits exclude cooldown and vanilla weather.
Constants.WEATHER_PROBABILITIES = {
    1.0 / (144.0 * 30.0),
    1.0 / (144.0 * 20.0),
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

Constants.SEASON_PROFILE_BY_ID = {
    [0] = "Spring",
    [1] = "Spring",
    [2] = "Summer",
    [3] = "Summer",
    [4] = "Fall",
    [5] = "Winter",
}

ChangingSkies.Constants = Constants
