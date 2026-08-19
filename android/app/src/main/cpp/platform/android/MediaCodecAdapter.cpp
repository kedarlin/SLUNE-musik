#include "MediaCodecAdapter.h"

#include "../../common/Logger.h"

MediaCodecAdapter::MediaCodecAdapter()
{
}

MediaCodecAdapter::~MediaCodecAdapter()
{
    close();
}

bool MediaCodecAdapter::open(IDataSource &source)
{
    if (!extractor_.open(source))
    {
        return false;
    }

    if (!extractor_.readMetaData())
    {
        return false;
    }

    if (!codec_.initialize(extractor_.state()))
    {
        return false;
    }

    LOGI("MediaCodecAdapter opened.");

    return true;
}

void MediaCodecAdapter::close()
{
    codec_.close();
    extractor_.close();
    LOGI("MediaCodecAdapter closed.");
}

ProcessResult MediaCodecAdapter::decode(AudioBuffer &buffer)
{
    return codec_.decode(extractor_.state(), buffer);
}

bool MediaCodecAdapter::seek(int64_t positionUs)
{
    if (!codec_)
    {
        return false;
    }

    LOGI("Seeking to %lld us", static_cast<long long>(positionUs));

    AMediaCodec_flush(codec_);

    if (!extractor_.seek(positionUs))
    {
        return false;
    }

    return true;
}