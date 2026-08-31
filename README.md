# Changing Skies

Changing Skies is a small Project Zomboid Build 42.20 foundation built around one rule: vanilla owns the weather and this mod only influences it.

## Known limitation: out-of-season ground snow

Sufficiently cold precipitation can fall as snow outside vanilla Winter, and vanilla can accumulate that snow numerically. However, in Build 42.20.4 the normal renderer does not display the accumulated ground-snow overlay outside vanilla Winter. This is a Build 42.20.4 renderer limitation, not a failure of the sandbox settings.

This milestone contains:

- four opt-in editable seasonal temperature ranges based on fixed vanilla Normal references
- matching snow/rain correction from the composed final temperature
- an additive scheduler that asks vanilla for generated weather or a configured Heavy Precipitation, Tropical Storm, or Blizzard stage only when no `WeatherPeriod` is active
- a Vanilla Seasonal storm choice that leaves pattern, season-aware severe selection, and duration generation to vanilla
- fixed storm-length bands or a random 4-100 hour exact-stage length
- optional sound-only thunder cracks during all weather, storm stages only, or vanilla thunderstorms, using vanilla thunder events without forcing lightning flashes
- namespaced, schema-versioned scheduler state in `ClimateManager:getModData().ChangingSkies`
- server/SP authority guards and no custom networking or client Lua.

Ordinary added weather is enabled by default with a conservative frequency preset and a 24-72 world-hour cooldown after any observed weather period ends. Guaranteed storms and added thunder default to Off, preserving existing-save behavior until configured. Storm opportunities roll before ordinary added weather and share its non-overlap and cooldown rules. Seasonal target temperatures remain disabled until configured. When enabled, Changing Skies converts each range endpoint's difference from its vanilla Normal reference into the internal temperature delta, retaining vanilla daily and weather variation.

Exact Storm Length applies only to the exact Heavy Precipitation, Tropical Storm, Blizzard, and Random Extreme choices. Ordinary generated weather and Vanilla Seasonal use vanilla duration because the vanilla generation request does not expose a duration parameter. Added Thunder intentionally remains sound-only. Direct server thunder events do not re-check every client's disabled-lightning preference, so forcing a shared flash would override an accessibility setting.

## Current validation boundary

The standalone tests compile and execute the Lua modules with mocked Build 42.20 climate objects. They validate settings fallback, temperature math/composition, ownership relinquishment, generated-weather and storm priority/non-overlap, trigger verification, cooldown transitions, minute-deduplicated thunder placement, and read-only snow diagnostics.

A Build 42.20.4 SP pass confirmed the earlier generated-weather, temperature, snow, cooldown, Winter ground-accumulation, and ordinary-melt behavior. The test save also confirmed vanilla numeric snow accumulation during an Early Summer storm. Build 42.20.4's default FBO ground-snow renderer suppresses that accumulated snow outside vanilla Winter. SP live testing confirmed Insane Storm cadence and sustained Insane Added Thunder. The revised four-line menu, Vanilla Seasonal request, random exact-storm length, Added Thunder scope behavior, exact-stage save and reload, multiplayer, and join-in-progress remain unverified.

Run the standalone suite from PowerShell:

```powershell
.\tests\Run-Tests.ps1
```

## License

Changing Skies is available under the [MIT License](LICENSE).
