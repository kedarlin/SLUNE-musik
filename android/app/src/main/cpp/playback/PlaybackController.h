#pragma once

#include "../engine/PlaybackWorker.h"
#include "../decoder/IDecoder.h"
#include "../common/AudioFifo.h"
#include "../pipeline/AudioBuffer.h"
#include "../pipeline/ProcessResult.h"

#include <vector>

static constexpr int kDefaultCallbackFrames = 256;

class PlaybackController
{
public:
    PlaybackController();

    bool initialize(IDecoder &decoder);

    ProcessResult render(AudioBuffer &outputBuffer);

    void clear();

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

    static constexpr size_t kLowWaterMarkFrames = 1024;

    PlaybackWorker worker_;
};