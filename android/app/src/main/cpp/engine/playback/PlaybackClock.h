#pragma once

#include "PlaybackMetadata.h"
#include "PlaybackState.h"

#include <atomic>
#include <cstdint>

struct PlaybackSnapshot
{
    double playbackPositionSeconds = 0.0;
    double mediaPositionSeconds = 0.0;
    double playbackDurationSeconds = 0.0;
    double mediaDurationSeconds = 0.0;
    double progress = 0.0;
    float playbackSpeed = 1.0f;
    int64_t renderedFrames = 0;
};

class PlaybackClock
{
public:
    static PlaybackSnapshot snapshot(
        const PlaybackMetadata &metadata,
        const PlaybackState &state);
};