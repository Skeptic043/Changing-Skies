$ErrorActionPreference = "Stop"

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$buildDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".build"))
$gameJar = "C:\Steam Games\steamapps\common\ProjectZomboid\projectzomboid.jar"
$javac = "C:\Program Files\JetBrains\IntelliJ IDEA 2026.1.1\jbr\bin\javac.exe"
$java = "C:\Steam Games\steamapps\common\ProjectZomboid\jre64\bin\java.exe"

if (-not (Test-Path -LiteralPath $gameJar)) {
    throw "Build 42.20 projectzomboid.jar was not found at $gameJar"
}
if (-not (Test-Path -LiteralPath $javac) -or -not (Test-Path -LiteralPath $java)) {
    throw "The inspected Java 25 compiler/runtime pair was not found."
}
if (-not $buildDirectory.StartsWith($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a build directory outside the Changing Skies repository."
}

try {
    if (Test-Path -LiteralPath $buildDirectory) {
        Remove-Item -LiteralPath $buildDirectory -Recurse -Force
    }
    New-Item -ItemType Directory -Path $buildDirectory | Out-Null

    & $javac -encoding UTF-8 -cp $gameJar -d $buildDirectory (Join-Path $PSScriptRoot "LuaTestRunner.java")
    if ($LASTEXITCODE -ne 0) {
        throw "Lua test runner compilation failed with exit code $LASTEXITCODE"
    }

    $classPath = $buildDirectory + ";" + $gameJar
    Push-Location (Split-Path -Parent $gameJar)
    try {
        & $java -cp $classPath LuaTestRunner $repositoryRoot
        $luaTestExitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($luaTestExitCode -ne 0) {
        throw "Lua tests failed with exit code $luaTestExitCode"
    }

    $modRoot = Join-Path $repositoryRoot "Contents\mods\ChangingSkies\42.20"
    $modInfo = Get-Content -LiteralPath (Join-Path $modRoot "mod.info") -Raw
    if ($modInfo -notmatch "(?m)^id=ChangingSkies$") {
        throw "mod.info is missing id=ChangingSkies"
    }
    $modInfoWarning = "Out-of-season snow may fall, but accumulated ground snow is only displayed during vanilla Winter."
    if (-not $modInfo.Contains($modInfoWarning)) {
        throw "mod.info is missing the approved out-of-season ground-snow warning."
    }

    $readme = Get-Content -LiteralPath (Join-Path $repositoryRoot "README.md") -Raw
    $limitationHeading = "## Known limitation: out-of-season ground snow"
    $featureListMarker = "This milestone contains:"
    $headingIndex = $readme.IndexOf($limitationHeading)
    $featureListIndex = $readme.IndexOf($featureListMarker)
    if ($headingIndex -lt 0 -or $featureListIndex -lt 0 -or $headingIndex -gt $featureListIndex) {
        throw "README out-of-season ground-snow limitation must appear before the feature list."
    }
    $readmeLimitationMeaning = @(
        "Sufficiently cold precipitation can fall as snow outside vanilla Winter, and vanilla can accumulate that snow numerically.",
        "However, in Build 42.20.4 the normal renderer does not display the accumulated ground-snow overlay outside vanilla Winter.",
        "This is a Build 42.20.4 renderer limitation, not a failure of the sandbox settings."
    )
    foreach ($requiredMeaning in $readmeLimitationMeaning) {
        if (-not $readme.Contains($requiredMeaning)) {
            throw "README out-of-season ground-snow limitation is missing approved meaning."
        }
    }

    $sandboxPath = Join-Path $modRoot "media\sandbox-options.txt"
    $sandbox = Get-Content -LiteralPath $sandboxPath -Raw
    if ($sandbox -notmatch "(?m)^VERSION\s*=\s*1,") {
        throw "sandbox-options.txt is missing VERSION = 1"
    }
    $optionCount = ([regex]::Matches($sandbox, "(?m)^option ChangingSkies\.")).Count
    if ($optionCount -ne 20) {
        throw "Expected 20 Changing Skies sandbox options, found $optionCount"
    }

    $expectedOptionIds = @(
        "EnableAddedWeather",
        "AddedWeatherFrequency",
        "AddedWeatherSeverity",
        "StormFrequency",
        "StormType",
        "StormLength",
        "AddedThunderFrequency",
        "AddedThunderScope",
        "CooldownMinimumHours",
        "CooldownMaximumHours",
        "EnableTemperatureAdjustment",
        "SpringColdTargetF",
        "SpringWarmTargetF",
        "SummerColdTargetF",
        "SummerWarmTargetF",
        "FallColdTargetF",
        "FallWarmTargetF",
        "WinterColdTargetF",
        "WinterWarmTargetF",
        "DebugLogging"
    )
    $declaredOptionIds = [regex]::Matches(
        $sandbox,
        "(?m)^option ChangingSkies\.(?<id>[A-Za-z0-9_]+)"
    ) | ForEach-Object { $_.Groups["id"].Value }
    $optionIdDifference = Compare-Object $expectedOptionIds $declaredOptionIds
    if ($optionIdDifference) {
        throw "Changing Skies sandbox option IDs do not match the expected 20-option schema."
    }
    if ($sandbox -match "(?m)^option ChangingSkies\.[A-Za-z]+AdjustmentF\s*\{") {
        throw "Retired *AdjustmentF sandbox option declarations must not be present."
    }

    $addedWeatherOption = [regex]::Match(
        $sandbox,
        "(?s)option ChangingSkies\.EnableAddedWeather\s*\{(?<body>.*?)\}"
    )
    if (-not $addedWeatherOption.Success -or
        $addedWeatherOption.Groups["body"].Value -notmatch "(?m)^\s*default\s*=\s*true,") {
        throw "EnableAddedWeather must default to true in sandbox-options.txt"
    }

    $frequencyOption = [regex]::Match(
        $sandbox,
        "(?s)option ChangingSkies\.AddedWeatherFrequency\s*\{(?<body>.*?)\}"
    )
    if (-not $frequencyOption.Success -or
        $frequencyOption.Groups["body"].Value -notmatch "(?m)^\s*numValues\s*=\s*6," -or
        $frequencyOption.Groups["body"].Value -notmatch "(?m)^\s*default\s*=\s*1,") {
        throw "AddedWeatherFrequency must expose six values and default to Very Low (1)."
    }

    $enumOptions = @(
        @("AddedWeatherSeverity", 6, 3, "ChangingSkies_Severity"),
        @("StormFrequency", 7, 1, "ChangingSkies_OptionalFrequency"),
        @("StormType", 5, 1, "ChangingSkies_StormType"),
        @("StormLength", 5, 2, "ChangingSkies_StormLength"),
        @("AddedThunderFrequency", 5, 1, "ChangingSkies_AddedThunderFrequency"),
        @("AddedThunderScope", 3, 1, "ChangingSkies_AddedThunderScope")
    )
    foreach ($enumOption in $enumOptions) {
        $id = $enumOption[0]
        $body = [regex]::Match(
            $sandbox,
            "(?s)option ChangingSkies\." + $id + "\s*\{(?<body>.*?)\}"
        )
        if (-not $body.Success -or
            $body.Groups["body"].Value -notmatch
                ("(?m)^\s*numValues\s*=\s*" + $enumOption[1] + ",") -or
            $body.Groups["body"].Value -notmatch
                ("(?m)^\s*default\s*=\s*" + $enumOption[2] + ",") -or
            $body.Groups["body"].Value -notmatch
                ("(?m)^\s*valueTranslation\s*=\s*" + $enumOption[3] + ",")) {
            throw "$id is missing its exact enum count, default, or value translation."
        }
    }

    $serverRoot = Join-Path $modRoot "media\lua\server\ChangingSkies"
    $constantsPath = Join-Path $serverRoot "Constants.lua"
    $constants = Get-Content -LiteralPath $constantsPath -Raw
    if ($constants -notmatch "(?m)^\s*enableAddedWeather\s*=\s*true,") {
        throw "EnableAddedWeather must default to true in Constants.lua"
    }
    if ($constants -notmatch "(?m)^\s*frequency\s*=\s*1,") {
        throw "The internal added-weather frequency default must be Very Low (1)."
    }

    $translationPath = Join-Path $modRoot "media\lua\shared\Translate\EN\Sandbox.json"
    $translations = Get-Content -LiteralPath $translationPath -Raw | ConvertFrom-Json
    if ($translations.Sandbox_ChangingSkies_EnableAddedWeather_tooltip -ne
        "Allows Changing Skies to ask the vanilla weather system to generate additional weather events.") {
        throw "Enable Added Weather tooltip does not match the approved copy."
    }
    if ($translations.Sandbox_ChangingSkies_AddedWeatherFrequency_tooltip -ne
        "Controls the chance for an added weather event, rolled every 10 in-game minutes. Cooldowns and naturally occurring weather add more time between checks.") {
        throw "Added Weather Frequency tooltip does not match the approved copy."
    }
    if ($translations.Sandbox_ChangingSkies_AddedWeatherSeverity -ne "Weather Strength" -or
        $translations.Sandbox_ChangingSkies_AddedWeatherSeverity_tooltip -ne
        "Controls the strength range for ordinary added weather. Vanilla still chooses its generated pattern, stages, type, and duration.") {
        throw "Weather Strength label or tooltip does not match the approved copy."
    }
    if ($translations.Sandbox_ChangingSkies_EnableTemperatureAdjustment_tooltip -ne
        "Applies the chosen seasonal temperatures while retaining vanilla daily and weather variation.") {
        throw "Enable Temperature Adjustment tooltip does not match the approved target-temperature copy."
    }

    $frequencyValues = @("Very Low", "Low", "Normal", "High", "Very High", "Insane")
    for ($index = 1; $index -le $frequencyValues.Count; $index++) {
        $key = "Sandbox_ChangingSkies_Frequency_option" + $index
        if ($translations.PSObject.Properties[$key].Value -ne $frequencyValues[$index - 1]) {
            throw "Added Weather Frequency option $index does not match the approved six-value order."
        }
        $severityKey = "Sandbox_ChangingSkies_Severity_option" + $index
        if ($translations.PSObject.Properties[$severityKey].Value -ne
            $frequencyValues[$index - 1]) {
            throw "Weather Strength option $index does not preserve its six-value meaning."
        }
    }
    foreach ($retiredIndex in 7, 8) {
        $key = "Sandbox_ChangingSkies_Frequency_option" + $retiredIndex
        if ($null -ne $translations.PSObject.Properties[$key]) {
            throw "Retired Added Weather Frequency option $retiredIndex must not be translated."
        }
    }

    $optionalFrequencyValues = @("Off", "Very Low", "Low", "Normal", "High", "Very High", "Insane")
    for ($index = 1; $index -le $optionalFrequencyValues.Count; $index++) {
        $key = "Sandbox_ChangingSkies_OptionalFrequency_option" + $index
        if ($translations.PSObject.Properties[$key].Value -ne
            $optionalFrequencyValues[$index - 1]) {
            throw "Optional frequency value $index does not match the exact seven-value order."
        }
    }
    $stormTypeValues = @("Seasonal", "Heavy Precipitation", "Tropical Storm", "Blizzard", "Random")
    $stormLengthValues = @(
        "Short (6-12 hours)",
        "Normal (12-24 hours)",
        "Long (24-48 hours)",
        "Extreme (48-96 hours)",
        "Random (4-240 hours)"
    )
    for ($index = 1; $index -le 5; $index++) {
        if ($translations.PSObject.Properties["Sandbox_ChangingSkies_StormType_option$index"].Value -ne
            $stormTypeValues[$index - 1] -or
            $translations.PSObject.Properties["Sandbox_ChangingSkies_StormLength_option$index"].Value -ne
            $stormLengthValues[$index - 1]) {
            throw "Storm type or length value $index does not match the approved copy."
        }
    }
    if ($translations.Sandbox_ChangingSkies_StormFrequency_tooltip -ne
        "Controls the chance for a storm. Note: Rolls for a storm are made before normal weather rolls. If both are set to Insane, storms will win every time." -or
        $translations.Sandbox_ChangingSkies_StormType_tooltip -ne
        "Selects the storm type. Seasonal chooses based on current season when a storm is rolled. Random chooses a random storm, disregarding the current season." -or
        $translations.Sandbox_ChangingSkies_StormLength -ne "Storm Length" -or
        $translations.Sandbox_ChangingSkies_StormLength_tooltip -ne
        "Selects the approximate range rolled Storms will be." -or
        $translations.Sandbox_ChangingSkies_AddedThunderFrequency_tooltip -ne
        "Controls how often thunder is added." -or
        $translations.Sandbox_ChangingSkies_AddedThunderScope -ne "Added Thunder Scope" -or
        $translations.Sandbox_ChangingSkies_AddedThunderScope_tooltip -ne
        "Selects when Added Thunder can play. This does not change thunder created by vanilla weather.") {
        throw "Storm or Added Thunder tooltip does not match the approved copy."
    }

    $thunderFrequencyValues = @("Off", "Low", "Normal", "High", "Insane")
    for ($index = 1; $index -le $thunderFrequencyValues.Count; $index++) {
        $key = "Sandbox_ChangingSkies_AddedThunderFrequency_option$index"
        if ($translations.PSObject.Properties[$key].Value -ne
            $thunderFrequencyValues[$index - 1]) {
            throw "Added Thunder Frequency option $index does not match the approved order."
        }
    }
    foreach ($retiredIndex in 6, 7) {
        $key = "Sandbox_ChangingSkies_AddedThunderFrequency_option$retiredIndex"
        if ($null -ne $translations.PSObject.Properties[$key]) {
            throw "Retired Added Thunder Frequency option $retiredIndex must not be translated."
        }
    }

    $thunderScopeValues = @("All Weather", "Storms Only", "Vanilla Thunderstorms")
    for ($index = 1; $index -le 3; $index++) {
        if ($translations.PSObject.Properties["Sandbox_ChangingSkies_AddedThunderScope_option$index"].Value -ne
            $thunderScopeValues[$index - 1]) {
            throw "Added Thunder Scope option $index does not match the approved order."
        }
    }

    foreach ($season in "Spring", "Summer", "Fall", "Winter") {
        $titleKey = "Sandbox_Title_ChangingSkies_" + $season + "TemperatureTargetRange"
        if ($null -ne $translations.PSObject.Properties[$titleKey]) {
            throw "$season ignored custom-title translation must not be present."
        }
        $titleDeclaration = "(?m)^\s*title\s*=\s*ChangingSkies_" +
            $season + "TemperatureTargetRange,"
        if ($sandbox -match $titleDeclaration) {
            throw "$season ignored custom title declaration must not be present."
        }
    }

    $targetOptions = @(
        @("SpringColdTargetF", 37, "Spring Temp Target Low", "Sets the Spring low temperature target in °F. Vanilla daily and weather variation can move beyond it."),
        @("SpringWarmTargetF", 66, "Spring Temp Target High", "Sets the Spring high temperature target in °F. Vanilla daily and weather variation can move beyond it."),
        @("SummerColdTargetF", 60, "Summer Temp Target Low", "Sets the Summer low temperature target in °F. Vanilla daily and weather variation can move beyond it."),
        @("SummerWarmTargetF", 89, "Summer Temp Target High", "Sets the Summer high temperature target in °F. Vanilla daily and weather variation can move beyond it."),
        @("FallColdTargetF", 42, "Fall Temp Target Low", "Sets the Fall low temperature target in °F. Vanilla daily and weather variation can move beyond it."),
        @("FallWarmTargetF", 71, "Fall Temp Target High", "Sets the Fall high temperature target in °F. Vanilla daily and weather variation can move beyond it."),
        @("WinterColdTargetF", 19, "Winter Temp Target Low", "Sets the Winter low temperature target in °F. Vanilla daily and weather variation can move beyond it."),
        @("WinterWarmTargetF", 48, "Winter Temp Target High", "Sets the Winter high temperature target in °F. Vanilla daily and weather variation can move beyond it.")
    )
    foreach ($target in $targetOptions) {
        $id = $target[0]
        $default = $target[1]
        $option = [regex]::Match(
            $sandbox,
            "(?s)option ChangingSkies\." + [regex]::Escape($id) + "\s*\{(?<body>.*?)\}"
        )
        if (-not $option.Success -or
            $option.Groups["body"].Value -notmatch "(?m)^\s*type\s*=\s*double," -or
            $option.Groups["body"].Value -notmatch "(?m)^\s*min\s*=\s*-150," -or
            $option.Groups["body"].Value -notmatch "(?m)^\s*max\s*=\s*200," -or
            $option.Groups["body"].Value -notmatch
                ("(?m)^\s*default\s*=\s*" + $default + ",")) {
            throw "$id is missing its approved numeric bounds or rounded default."
        }
        $labelKey = "Sandbox_ChangingSkies_" + $id
        $tooltipKey = $labelKey + "_tooltip"
        if ($translations.PSObject.Properties[$labelKey].Value -ne $target[2] -or
            $translations.PSObject.Properties[$tooltipKey].Value -ne $target[3]) {
            throw "$id label or tooltip does not match the approved target-temperature copy."
        }
    }

    $retiredTemperatureIds = @(
        "SpringTemperatureRangeF", "SummerTemperatureRangeF",
        "FallTemperatureRangeF", "WinterTemperatureRangeF"
    )
    foreach ($retiredId in $retiredTemperatureIds) {
        if ($sandbox -match ("option ChangingSkies\." + [regex]::Escape($retiredId)) -or
            $null -ne $translations.PSObject.Properties["Sandbox_ChangingSkies_$retiredId"] -or
            $null -ne $translations.PSObject.Properties["Sandbox_ChangingSkies_${retiredId}_tooltip"]) {
            throw "Retired temperature option $retiredId must not remain public."
        }
    }
    $settingsPath = Join-Path $serverRoot "Settings.lua"
    $settingsSource = Get-Content -LiteralPath $settingsPath -Raw
    if ($settingsSource -match "TemperatureRangeF" -or
        $settingsSource -match "parseTemperatureRange" -or
        $settingsSource -match "string\.match") {
        throw "Compound-string temperature parser residue must not remain in Settings.lua."
    }

    $forbidden = Select-String -Path (Join-Path $serverRoot "*.lua") -Pattern @(
        "forceSnow",
        "resetModded",
        "resetOverrides",
        "OnWeatherPeriodComplete",
        "startThunderCloud",
        "stopAllClouds",
        "stopWeatherAndThunder",
        "transmitServerTriggerLightning",
        "transmitClient",
        "transmit[A-Z]",
        "sendClientCommand"
    )
    if ($forbidden) {
        throw "A forbidden weather/climate ownership pattern was found in server Lua."
    }

    $bootstrap = Get-Content -LiteralPath (Join-Path $serverRoot "Bootstrap.lua") -Raw
    if ($bootstrap -notmatch "return not isClient\(\)") {
        throw "Bootstrap is missing its authoritative not-isClient guard."
    }

    $diagnosticsPath = Join-Path $serverRoot "SnowDiagnostics.lua"
    $diagnostics = Get-Content -LiteralPath $diagnosticsPath -Raw
    $diagnosticForbidden = Select-String -LiteralPath $diagnosticsPath -Pattern @(
        "forceSnow",
        "setSnowTarget",
        ":set[A-Z]",
        "triggerCustomWeather",
        "triggerCustomWeatherStage",
        "setCurSeason"
    )
    if ($diagnosticForbidden) {
        throw "SnowDiagnostics.lua contains a forbidden climate, weather, snow, or season mutation."
    }
    if ($bootstrap -notmatch 'require "ChangingSkies/SnowDiagnostics"' -or
        $bootstrap -notmatch "ChangingSkies\.SnowDiagnostics\.emit\(") {
        throw "Bootstrap must invoke SnowDiagnostics only from the authoritative climate-tick path."
    }
    if ($diagnostics -notmatch "previousCompletedTick\.composedSnow=" -or
        $diagnostics -notmatch "newTick\.csRequestedSnowTarget=") {
        throw "Snow diagnostics are missing the explicit previous/new tick labels."
    }

    $thunderPath = Join-Path $serverRoot "Thunder.lua"
    $thunder = Get-Content -LiteralPath $thunderPath -Raw
    if ($thunder -notmatch
        "triggerThunderEvent\(x, y, true, false, false\)" -or
        $bootstrap -notmatch 'require "ChangingSkies/Thunder"' -or
        $bootstrap -notmatch "ChangingSkies\.Thunder\.onClimateTick\(") {
        throw "Added Thunder is missing its exact sound-only event call or bootstrap wiring."
    }
    if ($thunder -notmatch "getCurrentStageID\(\)" -or
        $thunder -notmatch "isThunderStorm\(\)" -or
        $thunder -notmatch "isTropicalStorm\(\)" -or
        $thunder -match "hasStorm\(" -or
        $thunder -match "hasTropical\(" -or
        $thunder -match "hasHeavyRain\(") {
        throw "Added Thunder scope must use active-stage and current vanilla storm state only."
    }
    if ($thunder -notmatch "lastTriggeredThunderMinuteSlot" -or
        $thunder -notmatch "THUNDER_MINIMUM_INTERVAL_MINUTES" -or
        $thunder -notmatch "lastTriggeredSlot > slot") {
        throw "Added Thunder is missing the persisted five-minute success throttle or future-slot repair."
    }
    $weatherPath = Join-Path $serverRoot "Weather.lua"
    $weather = Get-Content -LiteralPath $weatherPath -Raw
    if ($weather -match "triggerCustomWeather\(1\.0, true\)" -or
        $weather -notmatch "getSeason\(\)" -or
        $weather -notmatch "SEASONAL_STORM_STAGE_BY_EROSION_SEASON" -or
        $weather -notmatch "triggerCustomWeatherStage\(stageId, middleDurationHours\)" -or
        $weather -notmatch "nominalTotalHours - 2\.0" -or
        $weather -notmatch "RANDOM_STORM_DURATION_MINIMUM" -or
        $weather -notmatch "RANDOM_STORM_DURATION_MAXIMUM") {
        throw "Weather is missing guaranteed Seasonal mapping or bounded nominal duration subtraction."
    }
    $runner = Get-Content -LiteralPath (Join-Path $PSScriptRoot "LuaTestRunner.java") -Raw
    if ($runner -notmatch '"Weather\.lua",\s*"Thunder\.lua",\s*"SnowDiagnostics\.lua"') {
        throw "Lua test runner must load Thunder.lua in production module order."
    }
    if ($readme -notmatch "Temperature work is one global climate calculation per in-game minute, not one calculation per player" -or
        $readme -notmatch "Added Thunder scans online players only after an eligible roll succeeds" -or
        $readme -notmatch "Debug Logging is disabled by default and can produce substantial log I/O" -or
        $readme -notmatch "Vanilla suppresses thunder audio while local speed controls exceed normal speed" -or
        $readme -notmatch "remain unverified") {
        throw "README must document the M13 architecture, performance facts, and honest live boundary."
    }

    $publicCopyPaths = @(
        (Join-Path $repositoryRoot "README.md"),
        (Join-Path $modRoot "mod.info"),
        $translationPath
    )
    foreach ($publicCopyPath in $publicCopyPaths) {
        if (Select-String -LiteralPath $publicCopyPath -SimpleMatch ";") {
            throw "Public-facing copy contains a forbidden semicolon in $publicCopyPath"
        }
    }

    Write-Host "Static checks passed: public snow limitation and honest M13 live boundary; exact 20-option schema and order; eight numeric temperature targets; guaranteed Seasonal and bounded nominal storm duration; five-value Added Thunder with success throttle; active-stage thunder scope; no public semicolons; exact sound-only thunder flags; authority guard and expanded forbidden-pattern scan."
}
finally {
    if (Test-Path -LiteralPath $buildDirectory) {
        Remove-Item -LiteralPath $buildDirectory -Recurse -Force
    }
}
