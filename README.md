# Changing Skies

Changing Skies is a small Project Zomboid Build 42.20 foundation built around one rule: vanilla owns the weather; this mod only influences it.

This milestone contains:

- opt-in seasonal cold and warm target temperatures based on fixed vanilla Normal references;
- matching snow/rain correction from the composed final temperature;
- an additive scheduler that calls vanilla `triggerCustomWeather` only when no `WeatherPeriod` is active;
- namespaced, schema-versioned scheduler state in `ClimateManager:getModData().ChangingSkies`;
- server/SP authority guards and no custom networking or client Lua.

Added weather is enabled by default with a conservative frequency preset and a 24-72 world-hour cooldown after any observed weather period ends. Seasonal target temperatures remain disabled until configured; when enabled, Changing Skies converts each target's difference from its vanilla Normal reference into the internal temperature delta, retaining vanilla daily and weather variation.

## Current validation boundary

The standalone tests compile and execute the Lua modules with mocked Build 42.20 climate objects. They validate settings fallback, temperature math/composition, ownership relinquishment, scheduler deduplication, non-overlap, trigger verification, cooldown transitions, and read-only snow diagnostics.

A Build 42.20.4 SP pass confirmed clean loading, strong seasonal temperature changes with retained daily variation, immediate live sandbox-setting changes, snow visuals, thunder during snow, weather/temperature persistence across a menu reload, generated weather starts, and configured cooldowns. The test save also confirmed vanilla numeric snow accumulation during an Early Summer storm; Build 42.20.4's default FBO ground-snow renderer suppresses that accumulated snow outside vanilla Winter. Winter ground rendering and melt behavior, multiplayer, and join-in-progress remain release acceptance gates.

Run the standalone suite from PowerShell:

```powershell
.\tests\Run-Tests.ps1
```

## License

Changing Skies is available under the [MIT License](LICENSE).
