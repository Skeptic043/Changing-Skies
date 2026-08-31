ChangingSkies = ChangingSkies or {}

local Constants = ChangingSkies.Constants
local Log = ChangingSkies.Log
local State = {}

local function fresh()
    return {
        schemaVersion = Constants.SCHEMA_VERSION,
        schedulerStatus = "BOOT",
        lastWeatherRunning = false,
        currentWeatherCreatedByChangingSkies = false,
    }
end

function State.ensure(climateManager)
    local modData = climateManager:getModData()
    local state = modData.ChangingSkies
    if type(state) ~= "table" or state.schemaVersion ~= Constants.SCHEMA_VERSION then
        if state ~= nil then
            Log.once("invalid-state", "Resetting incompatible or corrupted persisted state.")
        end
        state = fresh()
        modData.ChangingSkies = state
        return state
    end

    if type(state.schedulerStatus) ~= "string" then
        state.schedulerStatus = "BOOT"
    end
    if type(state.lastWeatherRunning) ~= "boolean" then
        state.lastWeatherRunning = false
    end
    if type(state.currentWeatherCreatedByChangingSkies) ~= "boolean" then
        state.currentWeatherCreatedByChangingSkies = false
    end
    if type(state.lastProcessedTenMinuteSlot) ~= "number" then
        state.lastProcessedTenMinuteSlot = nil
    end
    if type(state.cooldownUntilWorldAgeHours) ~= "number" then
        state.cooldownUntilWorldAgeHours = nil
    end
    local thunderSlot = state.lastProcessedThunderMinuteSlot
    if type(thunderSlot) ~= "number" or thunderSlot ~= thunderSlot or
        thunderSlot == math.huge or thunderSlot == -math.huge or
        thunderSlot ~= math.floor(thunderSlot) then
        state.lastProcessedThunderMinuteSlot = nil
    end
    local triggeredThunderSlot = state.lastTriggeredThunderMinuteSlot
    if type(triggeredThunderSlot) ~= "number" or
        triggeredThunderSlot ~= triggeredThunderSlot or
        triggeredThunderSlot == math.huge or triggeredThunderSlot == -math.huge or
        triggeredThunderSlot ~= math.floor(triggeredThunderSlot) then
        state.lastTriggeredThunderMinuteSlot = nil
    end
    return state
end

ChangingSkies.State = State
