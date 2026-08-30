# Changing Skies

Changing Skies is a small Project Zomboid Build 42.20 foundation built around one rule: vanilla owns the weather; this mod only influences it.

This milestone contains:

- opt-in seasonal cold-end and warm-end temperature adjustments relative to vanilla;
- matching snow/rain correction from the composed final temperature;
- an additive scheduler that calls vanilla `triggerCustomWeather` only when no `WeatherPeriod` is active;
- namespaced, schema-versioned scheduler state in `ClimateManager:getModData().ChangingSkies`;
- server/SP authority guards and no custom networking or client Lua.

Added weather is enabled by default with a conservative frequency preset and a 24-72 world-hour cooldown after any observed weather period ends. Seasonal temperature adjustment remains disabled until configured.

## Current validation boundary

The standalone tests compile and execute the Lua modules with mocked Build 42.20 climate objects. They validate settings fallback, temperature math/composition, ownership relinquishment, scheduler deduplication, non-overlap, trigger verification, and cooldown transitions.

A first Build 42.20.4 SP pass confirmed clean loading, strong seasonal temperature adjustment with retained daily variation, snow visuals, thunder during snow, and weather/temperature persistence across a menu reload. It also exposed a stale live-sandbox-settings read, now corrected in source and awaiting a focused retest. Ground snow did not visibly accumulate during one long sub-zero storm. Multiplayer, join-in-progress, accumulation, and melt behavior remain release acceptance gates.

Run the standalone suite from PowerShell:

```powershell
.\tests\Run-Tests.ps1
```

## License

Changing Skies is available under the [MIT License](LICENSE).
