#pragma once

#include "AudioCallback.h"

#include "../pipeline/AudioPipeline.h"

#include <memory>
#include <oboe/Oboe.h>

class OboeOutput
{
public:
    OboeOutput();
    ~OboeOutput();

    bool initialize(EngineContext &context, AudioPipeline &pipeline);
    void shutdown();

private:
    // Multiple of framesPerBurst to size the output buffer to. 2 (the
    // previous value) was still producing audible dropouts; 4 gives more
    // headroom against scheduling jitter at the cost of a few ms more
    // output latency. Bump further only if dropouts persist - each step up
    // trades latency, not memory, since this is a few KB either way.
    static constexpr int32_t kBufferSizeBursts = 4;

    std::shared_ptr<oboe::AudioStream> stream_;
    std::unique_ptr<AudioCallback> callback_;
};