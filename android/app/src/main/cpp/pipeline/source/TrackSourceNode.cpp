#include "TrackSourceNode.h"

#include "../../common/AudioConverter.h"

// namespace
// {
//     static constexpr size_t kLowWaterMarkFrames = 2048;
//     static constexpr size_t kHighWaterMarkFrames = 8192;

// }

TrackSourceNode::TrackSourceNode(
    PlaybackController &playback) : playback_(playback)
{
}

ProcessResult TrackSourceNode::process(
    AudioBuffer &buffer)
{
    return playback_.render(buffer);
}