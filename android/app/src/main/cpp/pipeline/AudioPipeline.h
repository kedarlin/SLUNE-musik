#pragma once

#include <memory>
#include <vector>

#include "source/AudioSourceNode.h"
#include "effects/AudioEffectNode.h"

class AudioPipeline
{
public:
    AudioPipeline() = default;

    void setSource(std::unique_ptr<AudioSourceNode> source);
    void addEffect(std::unique_ptr<AudioEffectNode> effect);

    void process(
        float *buffer,
        int32_t numFrames,
        int32_t channelCount,
        float sampleRate);

private:
    std::unique_ptr<AudioSourceNode> source_;
    std::vector<std::unique_ptr<AudioEffectNode>> effects_;
};