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

bool MediaCodecDecoder::seek(int64_t positionMs)
{
    LOGI("MediaCodecDecoder::seek()");
    return adapter_.seek(positionMs);
}

ProcessResult MediaCodecDecoder::decode(
    AudioBuffer &buffer)
{
    static bool logged = false;

    if (!logged)
    {
        LOGI("MediaCodecDecoder::decode()");
        logged = true;
    }
    return adapter_.decode(buffer);
}