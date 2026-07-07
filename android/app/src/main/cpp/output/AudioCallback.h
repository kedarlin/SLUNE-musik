#pragma once

#include <oboe/Oboe.h>

#include "../pipeline/AudioPipeline.h"

class EngineContext;

class AudioCallback : public oboe::AudioStreamDataCallback
{
public:
    explicit AudioCallback(EngineContext &context);

    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream *audioStream,
        void *audioData,
        int32_t numFrames) override;

private:
    EngineContext &context_;

    AudioPipeline pipeline_;
};