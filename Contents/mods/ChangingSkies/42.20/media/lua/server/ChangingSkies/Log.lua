ChangingSkies = ChangingSkies or {}

local Log = {
    debugEnabled = false,
    emitted = {},
}

function Log.setDebugEnabled(enabled)
    Log.debugEnabled = enabled == true
end

function Log.info(message)
    print("[ChangingSkies] " .. tostring(message))
end

function Log.debug(message)
    if Log.debugEnabled then
        Log.info(message)
    end
end

function Log.once(key, message)
    if Log.emitted[key] then
        return
    end
    Log.emitted[key] = true
    Log.info(message)
end

ChangingSkies.Log = Log

