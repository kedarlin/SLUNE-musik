#include "MediaCodecDecoder.h"

#include "../common/Logger.h"
#include "../datasource/IDataSource.h"

bool MediaCodecDecoder::open(IDataSource &source)
{
    source_ = &source;
    LOGI("MedaiCodecDecoder::open()");

    return true;
}

void MediaCodecDecoder::close(const std::string &)
{
    LOGI("MedaiCodecDecoder::close()");

    return true;
}

ProcessResult MediaCodecDecoder::decode(AudioBuffer &)
{
    return ProcessResult::NoData;
}

bool MedaiCodecDecoder::seel(int64_t)
{
    LOGI("MediaCodecDecoder::seek()");
    return true;
}