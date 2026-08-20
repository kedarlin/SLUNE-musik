#include "PlaybackClock.h"

#include <algorithm>

PlaybackSnapshot PlaybackClock::snapshot(
    const PlaybackMetadata &metadata,
    const PlaybackState &state)
{
    PlaybackSnapshot snapshot;

    const auto renderedFrames =
        state.renderedFrames.load(std::memory_order_acquire);

    const auto speed =
        state.playbackSpeed.load(std::memory_order_acquire);

    const auto sampleRate =
        metadata.sampleRate;

    snapshot.renderedFrames = renderedFrames;
    snapshot.playbackSpeed = speed;

    if (sampleRate <= 0)
    {
        return snapshot;
    }

    snapshot.mediaPositionSeconds =
        static_cast<double>(renderedFrames) / sampleRate;

    snapshot.mediaDurationSeconds =
        metadata.durationSeconds();

    const double effectiveSpeed = speed > 0.0f ? speed : 1.0f;

    snapshot.playbackPositionSeconds =
        snapshot.mediaPositionSeconds / effectiveSpeed;

    snapshot.playbackDurationSeconds =
        snapshot.mediaDurationSeconds / effectiveSpeed;

    snapshot.progress =
        snapshot.mediaDurationSeconds > 0.0
            ? std::clamp(
                  snapshot.mediaPositionSeconds /
                      snapshot.mediaDurationSeconds,
                  0.0,
                  1.0)
            : 0.0;

    return snapshot;
}