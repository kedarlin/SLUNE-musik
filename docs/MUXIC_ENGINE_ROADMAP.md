# Muxic Audio Engine — Engineering Roadmap

## 1. Project Goal

Muxic is a Flutter music player with a custom native C++ audio engine.

The purpose of the native engine is to provide:
- low-latency PCM playback
- custom DSP
- time stretching
- pitch shifting
- accurate playback timing
- custom buffering
- future gapless/crossfade support

The engine is intentionally being built from the ground up rather than relying entirely on Android MediaPlayer/ExoPlayer.

---

## 2. Current Pipeline

Compressed audio file
        ↓
IDataSource
        ↓
AMediaExtractor
        ↓
ExtractorController
        ↓
AMediaCodec
        ↓
CodecController
        ↓
MediaCodecAdapter
        ↓
MediaCodecDecoder
        ↓
PlaybackController
        ↓
AudioFifo
        ↓
AudioConverter
        ↓
AudioPipeline
        ↓
DSP effects
        ↓
OboeOutput
        ↓
Android AudioTrack/device
