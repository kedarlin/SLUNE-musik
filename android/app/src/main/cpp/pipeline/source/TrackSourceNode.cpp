#include "TrackSourceNode.h"

#include "../../common/Logger.h"
#include "../../common/AudioConverter.h"

namespace
{
    constexpr size_t kLowWaterMarkFrames = 1024;
}

TrackSourceNode::TrackSourceNode(
    PlaybackController &playback) : playback_(playback)
{
}

ProcessResult TrackSourceNode::process(
    AudioBuffer &buffer)
{
    static bool logged = false;

    if (!logged)
    {
        LOGI("TrackSourceNode processing.");
        logged = true;
    }

    return playback_.render(buffer);
}