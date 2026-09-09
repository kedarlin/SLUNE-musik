#include "MediaCodecDecoder.h"

bool MediaCodecDecoder::open(IDataSource &source)
{
    return adapter_.open(source);
}

void MediaCodecDecoder::close()
{
    adapter_.close();
}

ProcessResult MediaCodecDecoder::seek(int64_t positionUs)
{
    if (!adapter_.seek(positionUs))
    {
        return ProcessResult::Error;
    }

    return ProcessResult::Continue;
}

ProcessResult MediaCodecDecoder::decode(
    AudioBuffer &buffer)
{
    return adapter_.decode(buffer);
}