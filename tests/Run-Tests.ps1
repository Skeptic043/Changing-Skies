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

    $sandboxPath = Join-Path $modRoot "media\sandbox-options.txt"
    $sandbox = Get-Content -LiteralPath $sandboxPath -Raw
    if ($sandbox -notmatch "(?m)^VERSION\s*=\s*1,") {
        throw "sandbox-options.txt is missing VERSION = 1"
    }
    $optionCount = ([regex]::Matches($sandbox, "(?m)^option ChangingSkies\.")).Count
    if ($optionCount -ne 15) {
        throw "Expected 15 Changing Skies sandbox options; found $optionCount"
    }

    $translationPath = Join-Path $modRoot "media\lua\shared\Translate\EN\Sandbox.json"
    Get-Content -LiteralPath $translationPath -Raw | ConvertFrom-Json | Out-Null

    $serverRoot = Join-Path $modRoot "media\lua\server\ChangingSkies"
    $forbidden = Select-String -Path (Join-Path $serverRoot "*.lua") -Pattern @(
        "forceSnow",
        "resetModded",
        "resetOverrides",
        "OnWeatherPeriodComplete"
    )
    if ($forbidden) {
        throw "A forbidden weather/climate ownership pattern was found in server Lua."
    }

    $bootstrap = Get-Content -LiteralPath (Join-Path $serverRoot "Bootstrap.lua") -Raw
    if ($bootstrap -notmatch "return not isClient\(\)") {
        throw "Bootstrap is missing its authoritative not-isClient guard."
    }

    Write-Host "Static checks passed: mod metadata, 15 sandbox options, translation JSON, authority guard, and forbidden-pattern scan."
}
finally {
    if (Test-Path -LiteralPath $buildDirectory) {
        Remove-Item -LiteralPath $buildDirectory -Recurse -Force
    }
}
