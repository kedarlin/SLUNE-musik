#pragma once

#include <atomic>
#include <cstdint>

struct PlaybackState
{
    std::atomic<int64_t> renderedFrames{0};
    std::atomic<float> playbackSpeed{1.f};
    std::atomic<bool> ended{false};

    void reset()
    {
        renderedFrames.store(0, std::memory_order_release);
        playbackSpeed.store(1.0f, std::memory_order_release);
        ended.store(false, std::memory_order_release);
    }

    void markEnded()
    {
        ended.store(true, std::memory_order_release);
    }

    void clearEnded()
    {
        ended.store(false, std::memory_order_release);
    }

    void addRenderedFrames(int64_t frames)
    {
        renderedFrames.fetch_add(
            frames,
            std::memory_order_release);
    }

    void setPlaybackSpeed(float speed)
    {
        playbackSpeed.store(
            speed,
            std::memory_order_release);
    }
};