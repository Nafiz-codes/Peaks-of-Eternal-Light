param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '../.tools/godot/Godot_v4.7.2-stable_win64_console.exe')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath. Supply -GodotPath with the installed console executable."
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectRoot '.tools/day20/test-logs'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$tests = @(
    'tests/simulation/test_mission_simulator.gd',
    'tests/simulation/test_member2_event_slotting.gd',
    'tests/simulation/test_member2_systems.gd',
    'tests/simulation/test_rover_expedition.gd',
    'tests/world/test_expedition_sites.gd',
    'tests/world/test_expedition_lifecycle.gd',
    'tests/world/test_developer_sol_skip.gd',
    'tests/world/test_rover_expedition.gd',
    'tests/world/test_orbital_motion.gd',
    'tests/world/test_sun_lighting.gd',
    'tests/world/test_live_operations.gd',
    'tests/world/test_rover_impact_rules.gd',
    'tests/world/test_lifeline_follow.gd',
    'tests/world/test_lifeline_cinematic.gd',
    'tests/world/test_crew_fieldwork.gd',
    'tests/ui/test_crew_dialogue.gd',
    'tests/world/test_lander_interior.gd',
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
