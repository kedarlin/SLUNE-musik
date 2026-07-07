#include "AudioCallback.h"

#include "../context/EngineContext.h"
#include "../pipeline/source/SineGeneratorNode.h"
#include "../common/Logger.h"

#include <algorithm>
#include <memory>

AudioCallback::AudioCallback(
    EngineContext &context)
    : context_(context)
{
    pipeline_.setSource(
        std::make_unique<SineGeneratorNode>());
}

oboe::DataCallbackResult AudioCallback::onAudioReady(
    oboe::AudioStream *audioStream,
    void *audioData,
    int32_t numFrames)
{
    static bool logged = false;

    if (!logged)
    {
        LOGI("Audio callback is running.");
        logged = true;
    }
    auto *output = static_cast<float *>(audioData);

    const int32_t channelCount = audioStream->getChannelCount();

    if (!context_.playing)
    {
        std::fill(
            output,
            output + (numFrames * channelCount),
            0.0f);

        return oboe::DataCallbackResult::Continue;
    }

    pipeline_.process(
        output,
        numFrames,
        channelCount,
        static_cast<float>(audioStream->getSampleRate()));

    return oboe::DataCallbackResult::Continue;
}