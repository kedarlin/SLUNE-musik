#pragma once

#include <atomic>

class EngineContext
{
public:
    EngineContext() = default;
    ~EngineContext() = default;

    std::atomic<float> playbackSpeed{1.0f};
    std::atomic<float> volume{1.0f};
    std::atomic<bool> initialized{false};
    std::atomic<bool> playing{false};
};