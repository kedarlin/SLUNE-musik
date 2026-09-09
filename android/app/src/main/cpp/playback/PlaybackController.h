#pragma once

#include "../engine/PlaybackWorker.h"
#include "../decoder/IDecoder.h"
#include "../decoder/MediaCodecDecoder.h"
#include "../common/AudioFifo.h"
#include "../pipeline/AudioBuffer.h"
#include "../pipeline/ProcessResult.h"
#include "../engine/playback/PlaybackState.h"

#include "SoundTouch.h"

#include <atomic>
#include <mutex>
#include <vector>

static constexpr int kDefaultCallbackFrames = 256;

class PlaybackController
{
public:
    PlaybackController(MediaCodecDecoder &decoder, PlaybackState &playbackState);

    bool initialize(IDecoder &decoder);

    void configureStretch(int sampleRate, int channels);

    void setStretchTempo(float tempo);

    void setStretchPitch(float pitch);

    ProcessResult render(AudioBuffer &outputBuffer);

    void clear();

    ProcessResult seek(int64_t positionUs);

    bool start();

    void stop();

    void fillFifo();

    bool isRunning() const;

    bool needsMoreData() const;

private:
    IDecoder *decoder_ = nullptr;

    AudioFifo fifo_{16384, 2};

    AudioBuffer decodedBuffer_;

    std::vector<int16_t> playbackBuffer_;

    std::vector<float> stretchInputBuffer_;

    soundtouch::SoundTouch stretcher_;

    bool stretchConfigured_ = false;

    std::atomic<bool> decoderReachedEnd_{false};

    static constexpr size_t kLowWaterMarkFrames = 2048;

    static constexpr size_t kHighWaterMarkFrames = 8192;

    PlaybackWorker worker_;

    PlaybackState &playbackState_;

    std::mutex decoderMutex_;
};