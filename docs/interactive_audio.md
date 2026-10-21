# Interactive game audio

`src/runtime/game_audio.gd` is the persistent `GameAudio` autoload registered in `project.godot`. It preloads three effects and owns their players across scene changes. Existing `MenuMusic` remains independent.

## Supplied assets

Original files are retained unchanged in `Assets/audio/sfx/`:

- `hover_source.mp3`: Mouse Button Hover.mp3.
- `click_source.mp3`: mouse click.mp3.
- `rover_start.mp3`: Rover starting sound.mp3, approximately 17.14 seconds.

`ui_hover.wav` isolates the hover reference from 2.90 to 3.13 seconds. The quiet source is amplified by 24 dB, with a 3 ms entrance fade and 20 ms exit fade. `ui_click.wav` keeps the first 0.24 seconds of the dedicated click, with a 20 ms exit fade. Both are separate stereo WAV assets; the sources are preserved. Hover selection was checked using silence/level analysis; subjective listening and speaker-specific tuning remain manual checks.

## UI integration and tuning

Existing and newly added BaseButtons (including texture buttons and checkboxes), OptionButtons and Sliders register automatically. Deferred registration uses instance IDs so deleted temporary controls are skipped safely. Existing UI scripts do not need individual audio players.

Mouse displacement divided by elapsed input time measures cursor speed. Exponential smoothing (rate 25) filters it, with a 3000 pixels/second input cap. Pitch maps 0–1800 pixels/second to 0.94–1.14 and clamps beyond that range. Idle speed decays after 120 ms. `hover_interval` sets a 75 ms minimum trigger interval. One hover player prevents stacked hover effects.

Hover checks the viewport's actual hovered control after mouse motion, suppressing obscured, disabled, hidden and noninteractive controls. Staying within the same control does not retrigger. Creating controls or changing keyboard focus alone does not play a mouse hover effect.

Button activation signals cover mouse and keyboard/controller UI acceptance. Slider keyboard changes and completed changed mouse drags give confirmation. A frame-level guard prevents duplicate click playback from overlapping handlers; distinct activations in the same frame are coalesced. The persistent player lets clicks finish across scene changes. Exit briefly waits for the click to finish before quitting.

`src/ui/lunar_navigation.gd` and `src/world/lunar_landing_selector.gd` call the same manager for confirmed direct Moon/outpost selection. Automatic completion of the sidebar approach does not add a second confirmation. Empty-space clicks and Moon rotation do not trigger the click API.

## Rover sequence

`src/world/rover_drive.gd` extends the existing controller with INACTIVE, STARTING and READY states. First throttle input after taking control starts the supplied clip and holds speed/velocity at zero. The player's `finished` signal unlocks existing movement after the full approximately 17-second clip; there is no arbitrary readiness timer.

Held throttle then uses existing acceleration. Released throttle leaves the rover ready and stationary. Ordinary stopping/starting does not replay startup. Exiting control or removing the rover cancels startup; reentry permits a new sequence. Pausing the game pauses rover audio and readiness, while UI effects remain available. This non-spatial sound represents the vehicle/simulator audio feed.

## Mixing and settings

- Hover: UI_SFX, player gain -6 dB.
- Click: UI_SFX, player gain -12 dB.
- Rover: Gameplay_SFX, player gain -12 dB.
- Both buses route through Effects, then Master, respecting existing saved effects/master volume settings. Music remains on its separate existing buses.

## Verification

`tests/ui/test_game_audio.gd` exercises real rendered pointer input, dynamic controls, bounded pitch, duplicate suppression, disabled/obscured controls, keyboard confirmation, pause, scene persistence, rover cancellation/reentry, actual audio completion and released/held throttle. `tests/world/test_live_operations.gd` includes sound-completion waits in the existing driving regression.

Additional regressions: `tests/ui/test_startup.gd`, `tests/ui/test_game_menu.gd` and `tests/ui/test_menu_music.gd`. Logs are in ignored `.tools/`. Existing imported rover UID fallback and test-exit ObjectDB warnings remain separate from this change. Hardware listening, controller-device testing and comparative performance profiling are not automated by these tests.
