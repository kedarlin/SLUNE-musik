#include "AudioCallback.h"

#include "../context/EngineContext.h"
#include "../pipeline/source/SineGeneratorNode.h"
#include "../pipeline/AudioNode.h"

#include <algorithm>
#include <memory>

AudioCallback::AudioCallback(
    EngineContext &context, AudioPipeline &pipeline)
    : context_(context), pipeline_(pipeline)
{
    // pipeline_.setSource(
    //     std::make_unique<SineGeneratorNode>());

    // pipeline_.setSource(
    //     std::make_unique<TrackSourceNode>(decoderModule.decoder()));
}

oboe::DataCallbackResult AudioCallback::onAudioReady(
    oboe::AudioStream *audioStream,
    void *audioData,
    int32_t numFrames)
{
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

    // Master gain, used for ducking when another app takes transient audio
    // focus. Just an atomic load and a multiply - no allocation, so it stays
    // real-time safe. Skipped entirely at unity gain.
    const float volume =
        context_.volume.load(std::memory_order_relaxed);

    if (volume != 1.0f)
    {
        const int32_t sampleCount = numFrames * channelCount;

        for (int32_t i = 0; i < sampleCount; ++i)
        {
            output[i] *= volume;
        }
    }

    return oboe::DataCallbackResult::Continue;
}
