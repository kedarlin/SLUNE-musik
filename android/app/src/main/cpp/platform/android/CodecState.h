#pragma once

#include <media/NdkMediaCodec.h>

struct CodecState
{
    AMediaCodec *codec = nullptr;
    bool configured = false;
    bool started = false;
    bool endOfStream = false;
    int64_t presentationTimeUs = 0;
};