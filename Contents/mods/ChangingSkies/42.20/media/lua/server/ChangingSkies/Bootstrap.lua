require "ChangingSkies/Constants"
require "ChangingSkies/Log"
require "ChangingSkies/Settings"
require "ChangingSkies/State"
require "ChangingSkies/Temperature"
require "ChangingSkies/Weather"

ChangingSkies = ChangingSkies or {}

local function authoritative()
    return not isClient()
end

local function onClimateTick(climateManager)
    if not authoritative() or climateManager == nil or not climateManager:isUpdated() then
        return
    end

    local settings = ChangingSkies.Settings.read()
    local state = ChangingSkies.State.ensure(climateManager)
    ChangingSkies.Temperature.apply(climateManager, settings)
    ChangingSkies.Weather.reconcile(
        climateManager,
        settings,
        state,
        GameTime.getInstance():getWorldAgeHours()
    )
end

local function everyTenMinutes()
    if not authoritative() then
        return
    end

    local climateManager = ClimateManager.getInstance()
    if climateManager == nil or not climateManager:isUpdated() then
        return
    end

    local settings = ChangingSkies.Settings.read()
    local state = ChangingSkies.State.ensure(climateManager)
    ChangingSkies.Weather.onTenMinutes(
        climateManager,
        settings,
        state,
        GameTime.getInstance():getWorldAgeHours()
    )
end

if not ChangingSkies.eventsRegistered then
    Events.OnClimateTick.Add(onClimateTick)
    Events.EveryTenMinutes.Add(everyTenMinutes)
    ChangingSkies.eventsRegistered = true
    ChangingSkies.Log.info("Build 42.20 foundation loaded.")
end
