# Changing Skies

Changing Skies is a small Project Zomboid Build 42.20 foundation built around one rule: vanilla owns the weather and this mod only influences it.

## Known limitation: out-of-season ground snow

Sufficiently cold precipitation can fall as snow outside vanilla Winter, and vanilla can accumulate that snow numerically. However, in Build 42.20.4 the normal renderer does not display the accumulated ground-snow overlay outside vanilla Winter. This is a Build 42.20.4 renderer limitation, not a failure of the sandbox settings.

This milestone contains:

- eight numeric low and high seasonal temperature targets based on fixed vanilla Normal references
- matching snow/rain correction from the composed final temperature
- an additive scheduler that asks vanilla for generated weather or a configured Heavy Precipitation, Tropical Storm, or Blizzard stage only when no `WeatherPeriod` is active
- a Seasonal storm choice that maps the current vanilla season to one guaranteed severe vanilla stage
- fixed nominal total storm-length bands or a random 4-240 hour nominal total
- optional sound-only thunder cracks during all weather, storm stages only, or vanilla thunderstorms, using vanilla thunder events without forcing lightning flashes
- namespaced, schema-versioned scheduler state in `ClimateManager:getModData().ChangingSkies`
- server/SP authority guards and no custom networking or client Lua.

Ordinary added weather is enabled by default with a conservative frequency preset and a 24-72 world-hour cooldown after any observed weather period ends. Guaranteed storms and added thunder default to Off. Storm Type defaults to Seasonal. Storm opportunities roll before ordinary added weather and share its non-overlap and cooldown rules. Seasonal target temperatures remain disabled until configured. When enabled, Changing Skies converts each endpoint's difference from its vanilla Normal reference into the internal temperature delta, retaining vanilla daily and weather variation.

Storm Length is an approximate nominal total that includes vanilla's one-hour START and CLEARING transitions. Seasonal, Heavy Precipitation, Tropical Storm, Blizzard, and Random each request exactly one vanilla severe stage. Added Thunder intentionally remains sound-only. Direct server thunder events do not re-check every client's disabled-lightning preference, so forcing a shared flash would override an accessibility setting.

Temperature work is one global climate calculation per in-game minute, not one calculation per player. Added Thunder scans online players only after an eligible roll succeeds, then broadcasts one vanilla event when a valid target is available. A successful Added Thunder event starts a five-world-minute minimum interval. Debug Logging is disabled by default and can produce substantial log I/O during accelerated testing. Vanilla suppresses thunder audio while local speed controls exceed normal speed, so server event logs do not prove audible playback.

## Current validation boundary

The standalone tests compile and execute the Lua modules with mocked Build 42.20 climate objects. They validate settings fallback, temperature math/composition, ownership relinquishment, generated-weather and storm priority/non-overlap, trigger verification, cooldown transitions, minute-deduplicated thunder placement, and read-only snow diagnostics.

A Build 42.20.4 SP pass confirmed the earlier generated-weather, temperature, snow, cooldown, Winter ground-accumulation, and ordinary-melt behavior. The test save also confirmed vanilla numeric snow accumulation during an Early Summer storm. Build 42.20.4's default FBO ground-snow renderer suppresses that accumulated snow outside vanilla Winter. SP live testing previously confirmed Insane Storm cadence and sustained Insane Added Thunder before the current changes. The restored numeric target controls, guaranteed Seasonal mapping, nominal total lengths, five-minute thunder throttle, save and reload behavior, multiplayer, and join-in-progress remain unverified live.

Run the standalone suite from PowerShell:

```powershell
.\tests\Run-Tests.ps1
```

## License

Changing Skies is available under the [MIT License](LICENSE).
