# Muxic Audio Engine — Engineering Roadmap

## 1. Project Goal

Muxic is a Flutter music player cloning MX Player's music module. Playback is built on
**Media3 ExoPlayer (Kotlin)**, not a custom native engine — a native C++/Oboe engine was
built and shipped a working feature set (seeking, SoundTouch-based speed/pitch, gapless
via manual FIFO management), but was retired for a mature library after repeated jitter/
dropout tuning cycles and a real crash class (hand-rolled queue index arithmetic). See
`CLAUDE.md` for the current architecture and active development rules.

The features this roadmap tracks:
- gapless queue playback, shuffle, repeat (native to ExoPlayer)
- independent speed/pitch ("slowed" audio) via Sonic
- equalizer, bass boost, virtualizer, reverb (`android.media.audiofx`)
- A-B loop
- offline lyrics (tags/.lrc first, on-device ASR later)
- background playback, media notification, lock screen, Bluetooth/headset controls

## 2. Current Pipeline

```
Flutter UI  (unchanged across the engine rewrite)
   |  bloc events
MusicControllerBloc
   |  MethodChannel muxic/player   +   EventChannel muxic/player_events
PlayerChannel                                         [Kotlin]
   |  MediaController (SessionToken)
PlaybackService : MediaSessionService                 [Kotlin]
   |- ExoPlayer      queue, gapless, speed/pitch (Sonic), LoadControl buffering
   |- MediaSession   notification, lock screen, Bluetooth/headset, Android Auto
```

`MusicControllerBloc` never talks to ExoPlayer directly — it goes through
`PlayerClient` (`lib/service/player_client.dart`), which wraps the two platform
channels. `PlaybackService` owns the single `ExoPlayer`/`MediaSession` instance;
`MainActivity` never binds to it directly, only connects a `MediaController` via
`SessionToken`, same as any external Media3 client would.

## 3. Status

| Feature | Status |
|---|---|
| Playback, queue, gapless, shuffle, repeat | Done (ExoPlayer-native) |
| Speed / pitch | Done (`PlaybackParameters`, Sonic) |
| Media notification / lock screen / background | Done (Media3 `MediaSessionService`) |
| Decoder fallback + error recovery | Done (`onPlayerError` retry-then-skip) |
| Equalizer / bass boost / virtualizer | Not started — `android.media.audiofx` attached to `player.audioSessionId` (already exposed by `PlaybackService`) |
| Reverb ("slowed + reverb") | Not started — `PresetReverb` first; custom `AudioProcessor` chain seam already exists in `PlaybackService.buildRenderersFactory()` if presets prove insufficient |
| A-B loop | Not started — `player.createMessage{}.setPosition(...).setDeleteAfterDelivery(false)` |
| Lyrics (tags/.lrc) | Not started — no engine involvement needed |
| Lyrics (on-device ASR) | Not started, higher risk — speech models need source separation for sung vocals, which is too heavy for real-time on-device; scope needs revisiting before building |

## 4. Why not the C++/Oboe engine

The retired engine was funded by three problems, each solved by a mature player library:

- **Jitter/dropouts.** Real-time-thread logging was removed, then Oboe buffer sizing was
  tuned; the actual ceiling turned out to be `PerformanceMode::LowLatency` capping buffer
  capacity at ~11.6ms on a real test device regardless of anything else tried. Moving to
  `PerformanceMode::None` (ExoPlayer's approach — no low-latency mode by default) recovered
  ~42.8ms of headroom. A general-purpose player library gets this tuning for free.
- **Crashes.** Hand-written queue index bookkeeping produced a real `RangeError` on
  previous-track at index 0. ExoPlayer owns queue/index state internally; the bloc trusts
  its `currentIndex` from push events rather than recomputing it.
- **Maintenance weight.** ~3,200 lines of C++ plus a 200MB vendored Oboe checkout, all to
  reimplement decode → buffer → resample → output.
