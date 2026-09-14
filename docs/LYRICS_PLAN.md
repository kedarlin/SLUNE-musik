# Offline AI Lyrics — Plan

Status: **Phase A, B, C, and D implemented.**

## Goal

Show synced, line-level lyrics for the playing song. Resolve them in this
order: embedded tag → `.lrc` sidecar → app database → generate them on-device
with an offline speech model. The user can edit a draft and save it; saved
lyrics are reused on every future play.

Everything is offline. Model files are **not** bundled in the APK — they live
in a dedicated app folder and (later) come from a one-time cloud download.

## Storage layout

Everything lives under the app-specific external dir (no runtime permission,
survives a device media re-index, removed on uninstall):

```
Android/data/com.example.music/files/
  lyrics/
    <contentKey>.lrc                              # standard LRC, shareable
  models/
    asr/
      distil-small.en-encoder.int8.onnx
      distil-small.en-decoder.int8.onnx
      distil-small.en-tokens.txt
    vad/
      silero_vad.onnx
```

- `contentKey` = a stable hash of `fileSizeBytes | durationMs | lowercase(title)`
  so lyrics stick to a song across MediaStore id churn.
- The DB of record is Hive box `lyrics` (keyed by `contentKey`); the `.lrc`
  file is a shareable mirror, also readable by other players if copied next to
  the audio. "Share .lrc" (in the lyrics view's overflow menu) exports a
  nicely-named temp copy through the OS share sheet.
- The four model files above are exactly the standard sherpa-onnx release
  asset names for the distil-whisper `distil-small.en` int8 export and the
  Silero VAD model — drop them in as-is, no renaming. Until a cloud endpoint
  exists, place them there manually (adb push or a file manager);
  `ModelManager.isReady()` reports whether they're all present, and the UI
  degrades to "engine not installed" when they aren't.

## Data model

- `LyricLine { Duration time; String text }`
- `Lyrics { List<LyricLine> lines; bool synced; String? plainText; LyricsSource source; DateTime updatedAt }`
- `LyricsSource`: `tag` | `lrc` | `ai` | `edited` | `online` — **any
  `ai`-or-`online`-sourced lyrics are treated as an unreviewed draft** the
  first time the user actually looks at them (`LyricsBloc` sets `isDraft`
  from `source`). Saving a draft (whether edited or accepted as-is) upgrades
  its source to `edited`, so it never nags again.

## Phase A — lyrics infrastructure + UI (done)

- `LrcCodec` — parse/serialize LRC.
- `LyricsRepository` — `load`/`save`/`delete`/`exportForShare`, content-key
  hashing.
- `LyricsBloc` — resolves lyrics on song change, tracks the active line off
  the position stream, drives the generate/save/delete/share flow.
- `LyricsView` — replaces the turntable disc (tap disc, or the Lyrics
  button). Line-synced auto-scroll + highlight, tap a line to seek.
- `LyricsEditorPage` — line list with editable text, tap-to-sync timestamps,
  bulk paste, save.

## Phase B — on-device transcription (done)

Pipeline, in order:

1. **Native decode** (`LyricsAudioDecoder.kt`, MediaExtractor + MediaCodec) —
   any format the device's decoders support → downmixed to mono → (optionally)
   vocal-bandpassed (Phase C) → resampled to 16 kHz → written as a canonical
   16-bit PCM WAV to the app's temp dir. Runs on a plain background `Thread`.
2. **Foreground service** (`LyricsForegroundService.kt`) — holds the process
   alive with an ongoing notification (app icon, same as the main playback
   notification) while a job runs. Reference-counted in `LyricsChannel` so an
   overlapping cancel-and-restart can't yank the notification out from under
   a job still in progress.
3. **VAD + Whisper, in a spawned Dart isolate** (`sherpa_transcription_service.dart`,
   using the real `sherpa_onnx` package - verified against its actual API by
   fetching it and reading the source):
   - Silero VAD (`VoiceActivityDetector`) is fed the WAV in 512-sample windows
     and splits it into speech-shaped segments (`minSilenceDuration: 0.3s`,
     `maxSpeechDuration: 10s`). **A segment's start time becomes the line's
     timestamp.**
   - Each segment is decoded independently by an offline Whisper recognizer
     (`distil-small.en`, English, greedy search).
   - A light filter drops empty/punctuation-only results and immediate
     duplicate text (Whisper's instrumental-segment hallucination shapes).
   - Lines stream back to `LyricsBloc` progressively via the
     `TranscriptionProgress` contract from Phase A.
4. Cancellation kills the isolate, closes the receive port, stops the
   foreground service (decrementing its reference count), and deletes the
   temp WAV.

## Phase C — accuracy lever (done, revised from the original plan)

**Correction:** the original plan assumed sherpa-onnx shipped a Spleeter/UVR
style vocal-separation model. Having actually fetched and read the package
(v1.13.8), it does not - it has `OfflineSpeechDenoiser` (a *speech* denoiser,
for background noise, a different task from separating vocals out of
instrumentation) but no music source-separation model. Building real
separation (Spleeter/MDX-Net) would mean a second unverifiable ONNX
integration with hand-written STFT pre/post-processing - too much
unverifiable risk to ship blind.

**What shipped instead:** a cheap, honestly-scoped DSP nudge in
`LyricsAudioDecoder.kt` - a vocal-frequency bandpass (150 Hz high-pass, 5 kHz
low-pass, one-pole exponential filters) applied to the downmixed mono signal
before resampling. This cuts sub-bass and cymbal/hi-hat energy, leaving the
vocal fundamental + formant range relatively louder. It is **not** vocal
isolation - it's a small SNR nudge, on by default (`enhanceVocals: true`),
with no UI toggle since it costs virtually nothing extra to always apply.
Real separation stays a possible future addition if `distil-small.en`'s
accuracy on a full mix proves insufficient.

## Phase D — polish (done)

- **Generate-ahead - built, then removed.** Originally transcribed the
  *next* queued song in the background so it was ready by the time the user
  reached it. Reverted: it required its own foreground-service notification
  the user had no way to attribute to what they'd actually asked for
  ("silent notification pops up for a song I didn't even ask to generate"),
  and there is no way to make that notification optional - Android requires
  one for any background work of this shape. Given the choice between
  keeping automatic prefetch or making generation strictly opt-in, the user
  chose strictly opt-in: lyrics now only ever generate from an explicit tap,
  full stop. If revisited, it would need to be re-scoped around that
  constraint rather than just re-added.
- **`.lrc` sharing** - `LyricsRepository.exportForShare` writes a
  nicely-named temp copy; `LyricsView`'s overflow menu offers "Share .lrc"
  through the OS share sheet (`share_plus`).
- **Consistent app icon on every notification** - both the main Media3
  playback notification and this foreground service's notification use the
  app's own launcher icon (`R.mipmap.ic_launcher`) as their small icon,
  overriding Media3's bundled generic music-note default. Android renders a
  notification's small icon as a plain tinted silhouette from its alpha
  channel only (standard OS behaviour on API 21+, not something an app can
  opt out of) - a full-colour icon still reads fine at that size, just flat.
- **Word-level highlight** - deliberately not built. The user's own call
  earlier in this project: line-level is sufficient, revisit only if that
  proves wrong in practice.

## Phase E — online lookup (secondary, opt-in) (done)

The offline pipeline stays the app's primary, always-reliable path - it's what
works with no signal (long rides, trekking, etc.). But no ASR model, no matter
how well-tuned, can recover lyrics from vocals that are genuinely distorted or
buried under heavy reverb/lofi processing in the source audio. For that case
- and for anyone who simply has internet and wants more accurate,
human-sourced lyrics - there's a second, entirely manual "Search Online"
action.

- **Source: LRCLIB** (`lrclib.net`) - free, open, no API key. It's the only
  free lyrics database with synced (LRC-timed) results; Musixmatch is
  commercial/gated and Genius has no timestamps.
- **`OnlineLyricsService`** (`lib/core/services/online_lyrics_service.dart`,
  using `dio`) calls `GET /api/search?track_name=...&artist_name=...` and
  returns every candidate LRCLIB has - it never auto-picks a "best match".
  Only the song's own title/artist go out; no device identifiers, no
  analytics, no other endpoint anywhere in the app.
- **The user picks.** Tapping "Search Online" (in the empty-lyrics screen,
  the failed screen, or the toolbar's overflow menu) opens a bottom sheet
  listing every result like a list of `.lrc` files - track/artist/album/
  duration plus a "Synced"/"Plain"/"Instrumental" chip. Tapping a row selects
  it; nothing in the sheet ever navigates outside the app.
- **Same draft/save gate as AI generation.** A selected result is shown with
  `LyricsSource.online` and `isDraft = true` - a metadata match can still be
  the wrong version of a song, so it isn't trusted until the user hits Save
  (which upgrades it to `edited`, same as an AI draft).
- **Never automatic.** Online lookups are not triggered on song change or
  anywhere else - only an explicit tap starts one, so the app makes zero
  network calls unless the user asks for this specific feature. (This
  matches offline generation too, now that generate-ahead is gone - nothing
  in the lyrics feature ever runs without the user asking for it.)
- **Deferred, discussed but not built:** a more accurate offline generator
  (e.g. real vocal source separation) - a separate future piece of work.

## Renaming a song

The content key (`LyricsRepository.contentKey`) is `size|duration|title`, so
a title change orphans anything saved under the old key. The song-rename
feature (`lib/core/utils/rename_song.dart`, native side in
`android/.../library/SongsChannel.kt`) calls
`LyricsRepository.remapForRename(oldSong, newTitle)` right after a
successful rename - moves the Hive record and `.lrc` mirror from the old key
to the new one - before the library re-fetch would otherwise make the old
`SongModel` stale.

## Verification

`flutter build apk --debug` compiles clean end-to-end after every phase -
Kotlin (decoder/service/channel/reference-counting) and Dart (isolate/FFI
glue, share) all type-check, and every `sherpa_onnx` and `share_plus` call
was checked against the real fetched package source, not assumed.

**Not verified (needs a device):** actual accuracy, timing, whether the
vocal bandpass measurably helps, and real-world foreground-service behavior
under memory pressure with two jobs overlapping. That needs the four model
files in place and a real run.

## Distribution

Models ship via a one-time download from a cloud endpoint into `files/models/`.
No Play Store base-size problem. Until that endpoint exists, drop the four
model files into that folder manually.
