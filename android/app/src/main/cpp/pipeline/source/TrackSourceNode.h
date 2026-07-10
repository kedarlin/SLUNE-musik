#pragma once

#include "AudioSourceNode.h"
#include "../AudioBuffer.h"
#include "../../decoder/IDecoder.h"
#include "../../common/AudioFifo.h"

#include <vector>

class TrackSourceNode : public AudioSourceNode
{
public:
    explicit TrackSourceNode(IDecoder &decoder);
    ProcessResult process(AudioBuffer &buffer) override;

private:
    IDecoder &decoder_;
    AudioBuffer decodedBuffer_;
    AudioFifo fifo_{16384, 2};
    std::vector<int16_t> playbackBuffer_;
};