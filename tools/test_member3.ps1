param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '../.tools/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectRoot '.tools/day20/test-logs'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$tests = @(
    'tests/simulation/test_mission_simulator.gd',
    'tests/ui/test_mission_dashboard.gd',
    'tests/world/test_lunar_landing_selector.gd',
    'tests/world/test_lunar_landing_transition.gd',
    'tests/world/test_lunar_outpost.gd',
    'tests/world/test_landing_site_session.gd',
    'tests/world/test_outpost_integration.gd',
    'tests/world/test_outpost_navigation.gd',
    'tests/world/test_member3_days14_20.gd'
)
$failed = 0
foreach ($test in $tests) {
    $output = & $GodotPath --headless --path $projectRoot --script $test 2>&1
    $code = $LASTEXITCODE
    $output | Set-Content -LiteralPath (Join-Path $logDirectory ((Split-Path -Leaf $test) + '.log'))
    # Godot can return 0 after a GDScript runtime error: inspect diagnostics too.
    $unexpected = @($output | Where-Object {
        "$_" -match 'SCRIPT ERROR:|Parse Error:|ERROR:' -and
        "$_" -notmatch "Failed to open 'user://logs/godot.*\.log'|Failed to open log file for writing: user://logs/godot.log|Failed to read the root certificate store\."
    })
    if ($code -ne 0 -or $unexpected.Count -gt 0) {
        $failed++
        Write-Output "FAIL $test (exit $code)"
        $unexpected | Write-Output
    } else {
        Write-Output "PASS $test"
    }
}
Write-Output "$($tests.Count - $failed)/$($tests.Count) suites passed. Logs: $logDirectory"
if ($failed -gt 0) { exit 1 }
