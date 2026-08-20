#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>
#include <atomic>

class AudioFifo
{
public:
    AudioFifo(
        size_t capacityFrames,
        int32_t channels);

    size_t push(
        const int16_t *input,
        size_t frames);

    size_t pop(
        int16_t *output,
        size_t frames);

    void clear();

    size_t availableFrames() const;

    size_t freeFrames() const;

private:
    int32_t channels_;

    size_t capacityFrames_;

    std::atomic<size_t> readCount_;

    std::atomic<size_t> writeCount_;

    std::vector<int16_t> buffer_;
};