#include "MediaCodecAdapter.h"

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

    return true;
}

void MediaCodecAdapter::close()
{
    codec_.close();
    extractor_.close();
}

ProcessResult MediaCodecAdapter::decode(AudioBuffer &buffer)
{
    return codec_.decode(extractor_.state(), buffer);
}

bool MediaCodecAdapter::seek(int64_t positionUs)
{

    codec_.flush();

    return extractor_.seek(positionUs);
}