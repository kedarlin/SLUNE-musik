#pragma once

#include "AudioSourceNode.h"
#include "../AudioBuffer.h"
#include "../../decoder/IDecoder.h"
#include "../../common/AudioFifo.h"
#include "../../playback/PlaybackController.h"

#include <vector>

class TrackSourceNode : public AudioSourceNode
{
public:
    explicit TrackSourceNode(PlaybackController &playback);
    ProcessResult process(AudioBuffer &buffer) override;

private:
    PlaybackController &playback_;
};