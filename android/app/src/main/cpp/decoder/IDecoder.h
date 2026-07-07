#pragma once

#include "../pipeline/AudioBuffer.h"
#include "../pipeline/ProcessResult.h"

#include <string>

class IDecoder
{
public:
    virtual ~IDecoder() = default;

    virtual bool open(const std::string &filePath) = 0;

    virtual void close() = 0;

    virtual ProcessResult decode(AudioBuffer &buffer) = 0;

    virtual bool seek(int64_t positionMs) = 0;
};