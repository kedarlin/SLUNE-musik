#include "MediaCodecDecoder.h"

#include "../common/Logger.h"

bool MediaCodecDecoder::open(const std::string &)
{
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