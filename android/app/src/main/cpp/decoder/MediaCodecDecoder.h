#pragma once

#include "IDecoder.h"
#include "../platform/android/MediaCodecAdapter.h"

class MediaCodecDecoder : public IDecoder
{
public:
    bool open(IDataSource &source) override;
    void close() override;
    ProcessResult decode(AudioBuffer &buffer) override;
    ProcessResult seek(int64_t positionMs) override;
    int sampleRate() const
    {
        return adapter_.sampleRate();
    }

    int channelCount() const
    {
        return adapter_.channelCount();
    }

    int bitRate() const
    {
        return adapter_.bitRate();
    }

    int64_t durationUs() const
    {
        return adapter_.durationUs();
    }

private:
    MediaCodecAdapter adapter_;
};