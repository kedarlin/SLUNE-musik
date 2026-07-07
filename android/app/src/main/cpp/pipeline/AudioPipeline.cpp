#include "AudioPipeline.h"

#include "../common/Logger.h"

void AudioPipeline::setSource(
    std::unique_ptr<AudioSourceNode> source)
{
    source_ = std::move(source);
}

void AudioPipeline::addEffect(
    std::unique_ptr<AudioEffectNode> effect)
{
    effects_.push_back(std::move(effect));
}

void AudioPipeline::process(
    float *buffer,
    int32_t numFrames,
    int32_t channelCount,
    float sampleRate)
{

    static bool logged = false;
    if (!logged)
    {
        LOGI("Pipeline is processing.");
        logged = true;
    }

    AudioBuffer audioBuffer(buffer, numFrames, channelCount, sampleRate);
    if (source_)
    {
        auto result = source_->process(audioBuffer);
        if (result != ProcessResult::Continue)
        {
            return;
        }
    }

    for (auto &effect : effects_)
    {
        auto result = effect->process(audioBuffer);

        if (result != ProcessResult::Continue)
        {
            return;
        }
    }
}