#pragma once

#include "Idecoder.h"

class MediaCodecDecoder : public IDecoder
{
public:
    bool open(IDataSource &source) override;
    void close() override;
    ProcessResult decode(AudioBuffer &buffer) override;
    bool seek(int64_t positionMs) override;

private:
    IDataSource* source_ = nullptr;
};