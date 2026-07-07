#include "AudioPipeline.h"

void AudioPipeline::addNode(
    std::unique_ptr<AudioNode> node)
{
    nodes_.push_back(std::move(node));
}

void AudioPipeline::process(
    float *buffer,
    int32_t numFrames,
    int32_t channelCount,
    float sampleRate)
{
    for (auto &node : nodes_)
    {
        node->process(buffer, numFrames, channelCount, sampleRate);
    }
}