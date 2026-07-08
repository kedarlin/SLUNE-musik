#pragma once

#include "MediaCodecSession.h"
#include "../../datasource/IDataSource.h"
#include "../../pipeline/AudioBuffer.h"
#include "../../pipeline/ProcessResult.h"
#include "../../decoder/controller/CodecController.h"
#include "../../decoder/controller/ExtractorController.h"

class MediaCodecAdapter
{
public:
    MediaCodecAdapter();
    ~MediaCodecAdapter();

    bool open(IDataSource &source);
    void close();

    ProcessResult decode(AudioBuffer &buffer);
    bool seek(int64_t positionMs);

private:
    ExtractorController extractor_;
    CodecController codec_;
};