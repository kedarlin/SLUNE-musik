#pragma once

#include "../../pipeline/AudioBuffer.h"
#include "../../pipeline/ProcessResult.h"
#include "../../platform/android/CodecState.h"
#include "../../platform/android/ExtractorState.h"
#include "../../platform/android/CodecBufferState.h"

#include <vector>

class CodecController
{
public:
    CodecController() = default;
    ~CodecController();

    bool initialize(const ExtractorState &extractor);
    ProcessResult decode(const ExtractorState &extractor, AudioBuffer &buffer);

    void flush();
    void close();

private:
    bool queueInputBuffer(
        const ExtractorState &);
    ProcessResult dequeueOutputBuffer(const ExtractorState &, AudioBuffer &);
    CodecState state_;
    CodecBufferState buffers_;
    std::vector<int16_t> pcmBuffer_;
};