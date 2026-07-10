#pragma once

#include <media/NdkMediaCodec.h>

struct CodecBufferState
{
    ssize_t inputIndex = -1;

    ssize_t outputIndex = -1;

    AMediaCodecBufferInfo bufferInfo{};
};