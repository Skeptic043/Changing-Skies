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
    if ($optionCount -ne 19) {
        throw "Expected 19 Changing Skies sandbox options; found $optionCount"
    }

    $expectedOptionIds = @(
        "EnableAddedWeather",
        "AddedWeatherFrequency",
        "AddedWeatherSeverity",
        "StormFrequency",
        "StormType",
        "StormLength",
        "AddedThunderFrequency",
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
        throw "Changing Skies sandbox option IDs do not match the expected 19-option schema."
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
        @("StormType", 4, 1, "ChangingSkies_StormType"),
        @("StormLength", 4, 2, "ChangingSkies_StormLength"),
        @("AddedThunderFrequency", 7, 1, "ChangingSkies_OptionalFrequency")
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
    $stormTypeValues = @("Heavy Precipitation", "Tropical Storm", "Blizzard", "Random Extreme")
    $stormLengthValues = @(
        "Short (6-12 hours)",
        "Normal (12-24 hours)",
        "Long (24-48 hours)",
        "Extreme (48-96 hours)"
    )
    for ($index = 1; $index -le 4; $index++) {
        if ($translations.PSObject.Properties["Sandbox_ChangingSkies_StormType_option$index"].Value -ne
            $stormTypeValues[$index - 1] -or
            $translations.PSObject.Properties["Sandbox_ChangingSkies_StormLength_option$index"].Value -ne
            $stormLengthValues[$index - 1]) {
            throw "Storm type or length value $index does not match the approved copy."
        }
    }
    if ($translations.Sandbox_ChangingSkies_StormFrequency_tooltip -ne
        "Controls the chance for a guaranteed storm, rolled every 10 in-game minutes. Storm rolls before ordinary added weather; if both are Insane, Storm wins every eligible opening. Active weather and the shared cooldown still apply." -or
        $translations.Sandbox_ChangingSkies_StormType_tooltip -ne
        "Selects the guaranteed storm stage. Tropical Storm has inherent vanilla thunder; Blizzard snow still depends on temperature." -or
        $translations.Sandbox_ChangingSkies_StormLength_tooltip -ne
        "Selects the requested main-stage duration. Vanilla adds a one-hour start stage and a one-hour clearing stage." -or
        $translations.Sandbox_ChangingSkies_AddedThunderFrequency_tooltip -ne
        "Controls additive sound-only thunder during any active weather. It does not add lightning flashes and does not suppress vanilla thunder.") {
        throw "Storm or Added Thunder tooltip does not match the approved copy."
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
        @("SpringColdTargetF", "37.5", "Spring Cold", "Cold target for spring (March-May). Vanilla Normal reference: 37.5 F. Ordinary daily and weather variation can move beyond it."),
        @("SpringWarmTargetF", "66.3", "Warm", "Warm target for spring (March-May). Vanilla Normal reference: 66.3 F. Ordinary daily and weather variation can move beyond it."),
        @("SummerColdTargetF", "60.2", "Summer Cold", "Cold target for summer (June-August). Vanilla Normal reference: 60.2 F. Ordinary daily and weather variation can move beyond it."),
        @("SummerWarmTargetF", "89.0", "Warm", "Warm target for summer (June-August). Vanilla Normal reference: 89.0 F. Ordinary daily and weather variation can move beyond it."),
        @("FallColdTargetF", "42.4", "Fall Cold", "Cold target for fall (September-November). Vanilla Normal reference: 42.4 F. Ordinary daily and weather variation can move beyond it."),
        @("FallWarmTargetF", "71.2", "Warm", "Warm target for fall (September-November). Vanilla Normal reference: 71.2 F. Ordinary daily and weather variation can move beyond it."),
        @("WinterColdTargetF", "19.9", "Winter Cold", "Cold target for winter (December-February). Vanilla Normal reference: 19.9 F. Ordinary daily and weather variation can move beyond it."),
        @("WinterWarmTargetF", "48.7", "Warm", "Warm target for winter (December-February). Vanilla Normal reference: 48.7 F. Ordinary daily and weather variation can move beyond it.")
    )
    foreach ($target in $targetOptions) {
        $id = $target[0]
        $default = $target[1]
        $option = [regex]::Match(
            $sandbox,
            "(?s)option ChangingSkies\." + [regex]::Escape($id) + "\s*\{(?<body>.*?)\}"
        )
        if (-not $option.Success -or
            $option.Groups["body"].Value -notmatch "(?m)^\s*min\s*=\s*-150," -or
            $option.Groups["body"].Value -notmatch "(?m)^\s*max\s*=\s*200," -or
            $option.Groups["body"].Value -notmatch
                ("(?m)^\s*default\s*=\s*" + [regex]::Escape($default) + ",")) {
            throw "$id is missing its approved range or vanilla Normal default."
        }
        $labelKey = "Sandbox_ChangingSkies_" + $id
        $tooltipKey = $labelKey + "_tooltip"
        if ($translations.PSObject.Properties[$labelKey].Value -ne $target[2] -or
            $translations.PSObject.Properties[$tooltipKey].Value -ne $target[3]) {
            throw "$id label or tooltip does not match the approved target-temperature copy."
        }
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
    $runner = Get-Content -LiteralPath (Join-Path $PSScriptRoot "LuaTestRunner.java") -Raw
    if ($runner -notmatch '"Weather\.lua",\s*"Thunder\.lua",\s*"SnowDiagnostics\.lua"') {
        throw "Lua test runner must load Thunder.lua in production module order."
    }
    if ($readme -notmatch "Guaranteed storms and added thunder default to Off" -or
        $readme -notmatch "have not yet passed live acceptance") {
        throw "README must document the new architecture and remaining live boundary."
    }

    Write-Host "Static checks passed: public snow limitation and honest M11 live boundary; parsed exact 19-option schema/order/defaults; retained six-value Weather Frequency and Weather Strength meanings; exact Storm and Added Thunder enums/translations/tooltips; seasonal temperature labels/ranges; authoritative weather, thunder, and diagnostic wiring; exact sound-only thunder flags; runner production order; authority guard and expanded server-wide forbidden-pattern scan."
}
finally {
    if (Test-Path -LiteralPath $buildDirectory) {
        Remove-Item -LiteralPath $buildDirectory -Recurse -Force
    }
}
