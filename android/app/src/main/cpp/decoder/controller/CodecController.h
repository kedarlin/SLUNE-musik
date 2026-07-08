#pragma once

#include "../../pipeline/AudioBuffer.h"
#include "../../pipeline/ProcessResult.h"
#include "../../platform/android/CodecState.h"
#include "../../platform/android/ExtractorState.h"

class CodecController
{
public:
    CodecController() = default;
    ~CodecController();

    bool initialize(const ExtractorState &extractor);
    ProcessResult decode(AudioBuffer &buffer);

    void flush();
    void close();

private:
    CodecState state_;
};