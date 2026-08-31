# Audio drop folder

Put source audio here; it gets wired into `assets/audio/` and the game's audio
system from these folders (same workflow as Backgrounds and Character art).

- `music/` — title theme, exploration tracks, depth-band moods, red-moon tension
- `ambient/` — loops: underwater, dry-interior room tone, surface waves, machinery hum
- `sfx/` — one-shots: footsteps, splash/dive, scrap hits, block place/break, doors,
  breaker flip, pump running, UI clicks, item pickup

Formats: **OGG Vorbis** for music/ambient (loops cleanly), **WAV** for short SFX
(no decode latency); MP3 also works. Use descriptive names
(`underwater_loop.ogg`, `door_open.wav`). Volume matching happens at import.
