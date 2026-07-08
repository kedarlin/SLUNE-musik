#include "MediaCodecDecoder.h"

#include "../common/Logger.h"

bool MediaCodecDecoder::open(IDataSource &source)
{
    LOGI("MediaCodecDecoder::open()");
    return adapter_.open(source);
}

void MediaCodecDecoder::close()
{
    LOGI("MediaCodecDecoder::close()");
    adapter_.close();
}

ProcessResult MediaCodecDecoder::decode(AudioBuffer &buffer)
{
    return adapter_.decode(buffer);
}

bool MediaCodecDecoder::seek(int64_t positionMs)
{
    LOGI("MediaCodecDecoder::seek()");
    return adapter_.seek(positionMs);
}