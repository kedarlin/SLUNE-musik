#pragma once

#include <cmath>

#include "AudioBuffer.h"
#include "ProcessResult.h"

class AudioNode
{
public:
    virtual ~AudioNode() = default;

    virtual ProcessResult process(
        AudioBuffer &buffer) = 0;
};