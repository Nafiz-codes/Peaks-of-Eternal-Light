# Rover takeover and mission transitions

## Assets and preparation

The supplied `Astronaut_launches_lunar_rover_1080p_20261022011612.mp4` measures exactly 10 seconds, 1920×1080 at 24 fps, with H.264 video and AAC audio. The original Downloads file is untouched.

`Assets/video/rover_takeover_intro.ogv` is the active 1080p/24 fps Theora conversion at quality 8. It ends at 5.875 seconds (141 frames), immediately before the source's rear driving shot. It contains **only video, no audio stream**. The original ten-second conversion is retained as `rover_takeover.ogv`. The runtime also sets the VideoStreamPlayer volume to zero. Native Theora avoids an external playback plugin; see [Godot VideoStreamPlayer documentation](https://docs.godotengine.org/en/latest/classes/class_videostreamplayer.html).

`Assets/audio/sfx/rover_takeover.wav` preserves the complete mechanical sequence from `rover_start.mp3` using FFmpeg's pitch-preserving `atempo=1.7136`, padding/trimming to exactly 10 seconds, a 20 ms entrance fade and a 300 ms ending fade. Playback pitch stays 1.0. The source MP3 remains unchanged. This keeps the whole sequence instead of cutting off its final activation sounds; subjective listening remains useful for final artistic approval.

Reproduction filters:

```text
Video: -t 5.875 -an -c:v libtheora -q:v 8 -pix_fmt yuv420p
Audio: -af atempo=1.7136,apad,atrim=duration=10,afade=t=in:d=0.02,afade=t=out:st=9.7:d=0.3 -c:a pcm_s16le
```

## Control and visual handoff

`src/world/rover_takeover.gd` is one persistent-in-scene child of the existing RoverHull. It prepares the decoder during world setup. The existing `rover_drive.gd` validates a seated, available takeover, blocks astronaut/HUD interactions and enters STARTING immediately on R or the existing control button. No second driving controller is introduced.

The video fills the viewport with a 16:9 fit and letterboxing when needed. Its first 350 ms dissolve over the cockpit. Before the 5.875-second cut, the existing rover camera becomes current beneath the opaque video; the final 350 ms dissolve into the actual rover scene. This uses the rover's current in-game location, heading and normal driving-camera angle. The video layer then disappears, while the separate startup sound continues uninterrupted for its full ten seconds. The real rover remains stationary during the remaining roughly 4.125 seconds. Controls unlock on audio completion, with no further camera switch or sound restart.

Video decoding and audio use separate clocks. While the opening video plays, it gently follows the audio clock with a bounded 0.92–1.08 speed correction to recover rendering-stall drift; audio pitch and speed never change at runtime. The video intentionally finishes earlier than the audio. Pause freezes playback and readiness, including the live-rover remainder. Repeated R presses do nothing during takeover. A scene change, mission reset or loss of control eligibility cancels playback and restores normal state. A watchdog returns to the cockpit if playback fails to finish, rather than leaving controls locked. Reentry starts one fresh sequence.

The cutscene layer sits below the existing pause menu. Effects still route through Gameplay_SFX → Effects → Master. The mission soundtrack stays in its mission context.

## Music

`src/runtime/menu_music.gd` keeps both existing persistent players and adds a 2.5-second equal-power crossfade: menu gain `cos(blend × π/2)`, mission gain `sin(blend × π/2)`. Existing saved music/mission bus settings are applied independently. The outgoing player stops only after fading to zero, and its position is retained for the reverse transition. Repeated same-context scene changes do not restart the transition. An interrupted fade continues from its current gain.

During takeover, mission player gain smoothly ducks to 50% over 450 ms and recovers over 800 ms. Pause/resume does not restart either track. Muting and saved volume settings continue to work.

## Astronaut camera correction

The astronaut's `_ready()` ran before the dynamically created spring arm existed, so its self-collision exclusion was never applied. The arm could therefore retract into the astronaut capsule. `src/world/lunar_outpost.gd` now adds the exclusion immediately after constructing the arm.

`src/world/lunar_landing_blend.gd` freezes astronaut locomotion while allowing the arm to settle. `src/world/safe_arrival_camera.gd` builds a restrained spherical arc to the settled gameplay transform, instead of interpolating a straight line down toward an uninitialized camera. It derives a conservative body sphere from visual bounds and checks 65 path points plus swept 0.3 m camera spheres against nearby collision geometry. Radius is preserved around the astronaut, with smooth position/orientation easing and an exact final transform match.

If an arc is obstructed, the opposite arc or a safe stationary shot is used. If a nearby wall retracts the endpoint into the suit, an alternate gameplay orbit is selected while covered. Confined saved positions can fall back to the existing forward visor view, with a dissolve instead of an unsafe camera flight. Saved first-person/cockpit views also use the dissolve. The transition is owned by its destination scene so scene interruption disposes its camera/tween.

## Files

- New: `rover_takeover.gd`, `safe_arrival_camera.gd`, silent `.ogv`, processed `.wav`, this document, Windows `export_presets.cfg`, cinematic and arrival tests.
- Updated: `rover_drive.gd`, `lunar_outpost.gd`, `lunar_landing_blend.gd`, `game_audio.gd`, `menu_music.gd`, existing driving/music/audio tests and interactive audio notes.

## Verification and remaining limits

Executed on Godot 4.7.2, OpenGL compatibility, NVIDIA RTX 2050:

- Trimmed-video revision: 282 rendered transition assertions passed, including fullscreen fit, early live-rover handoff, uninterrupted audio and movement locking. The measured live-rover remainder was 4.024 seconds after pause/capture interruptions. FFprobe confirms 141 silent video frames (5.875 seconds); the sound remains exactly ten seconds.
- Before the trim revision, exported resource-pack playback passed 279 assertions via Godot's `--main-pack`, not a standalone export-template executable. That pack test validated native video playback; the new trim was verified in the project runtime.
- Existing rover driving: 53 assertions passed, including held throttle after takeover, steering, braking, damage and save state.
- Existing global audio and menu/mission music regressions passed.
- Actual arrival sequences across all four outposts and an obstructed spawn passed 506 rendered camera-clearance samples.
- FFprobe verified the silent video and exactly ten-second processed audio.

Logs/screenshots and the exported PCK are in ignored `.tools/`. `export_presets.cfg` exports resources and runtime JSON data; the video is a normal preloaded resource and was included in the tested pack. Windows export templates are not installed, so standalone EXE validation remains outstanding. Existing imported rover UID fallback and test-exit ObjectDB warnings remain. Broad hardware performance profiling, subjective soundtrack tuning and controller-device testing were not performed; the checks do not certify 60 FPS on every target.
