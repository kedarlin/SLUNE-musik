#pragma once

#include "IDecoder.h"
#include "../platform/android/MediaCodecAdapter.h"

class MediaCodecDecoder : public IDecoder
{
public:
    bool open(IDataSource &source) override;
    void close() override;
    ProcessResult decode(AudioBuffer &buffer) override;
    bool seek(int64_t positionMs) override;

private:
    MediaCodecAdapter adapter_;
};