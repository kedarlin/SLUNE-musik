#pragma once

#include <memory>
#include <vector>

#include "AudioNode.h"

class AudioPipeline
{
public:
    AudioPipeline() = default;

    void addNode(std::unique_ptr<AudioNode> node);

    void process(
        float *buffer,
        int32_t numFrames,
        int32_t channelCount,
        float sampleRate);
private:
    std::vector<std::unique_ptr<AudioNode>> nodes_;
};