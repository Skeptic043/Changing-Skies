# Changing Skies

Changing Skies is a small Project Zomboid Build 42.20 foundation built around one rule: vanilla owns the weather; this mod only influences it.

This milestone contains:

- opt-in seasonal cold-end and warm-end temperature adjustments relative to vanilla;
- matching snow/rain correction from the composed final temperature;
- an opt-in additive scheduler that calls vanilla `triggerCustomWeather` only when no `WeatherPeriod` is active;
- namespaced, schema-versioned scheduler state in `ClimateManager:getModData().ChangingSkies`;
- server/SP authority guards and no custom networking or client Lua.

Both features are disabled by default. Added weather uses conservative frequency presets and a 24-72 world-hour cooldown after any observed weather period ends.

## Current validation boundary

The standalone tests compile and execute the Lua modules with mocked Build 42.20 climate objects. They validate settings fallback, temperature math/composition, ownership relinquishment, scheduler deduplication, non-overlap, trigger verification, and cooldown transitions.

No live game, save/reload, multiplayer, out-of-season accumulation, or melt behavior has been tested yet. Source inspection supports the selected seams, but those runtime acceptance checks remain required before release claims.

Run the standalone suite from PowerShell:

```powershell
.\tests\Run-Tests.ps1
```

## License

Changing Skies is available under the [MIT License](LICENSE).
