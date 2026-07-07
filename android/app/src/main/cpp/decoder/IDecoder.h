#pragma once

#include "../pipeline/AudioBuffer.h"
#include "../pipeline/ProcessResult.h"
#include "../datasource/IDataSource.h"

#include <string>

class IDecoder
{
public:
    virtual ~IDecoder() = default;

    virtual bool open(IDataSource &source) = 0;

    virtual void close() = 0;

    virtual ProcessResult decode(AudioBuffer &buffer) = 0;

    virtual bool seek(int64_t positionMs) = 0;
};