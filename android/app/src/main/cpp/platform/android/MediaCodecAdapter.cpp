#include "MediaCodecAdapter.h"

#include "../../common/Logger.h"

MediaCodecAdapter::MediaCodecAdapter() : session_(std::make_unique<MediaCodecSession>())
{
}

MediaCodecAdapter::~MediaCodecAdapter()
{
    close();
}

bool MediaCodecAdapter::open(IDataSource &source)
{
    session_->source = &source;
    session_->extractor = AMediaExtractor_new();

    if (session_->extractor == nullptr)
    {
        LOGE("Failed to create MediaExtractor.");
        return false;
    }
    LOGI("MediaCodecAdapter opened.");

    return true;
}

void MediaCodecAdapter::close()
{
    LOGI("MediaCodecAdapter closed.");
    session_->source = nullptr;
}

ProcessResult MediaCodecAdapter::decode(AudioBuffer &)
{
    return ProcessResult::NoData;
}

bool MediaCodecAdapter::seek(int64_t)
{
    LOGI("MediaCodecAdapter seek.");

    return true;
}