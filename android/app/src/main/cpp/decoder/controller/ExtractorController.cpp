#include "ExtractorController.h"

#include "../../common/Logger.h"

bool ExtractorController::open(IDataSource &source)
{
    source_ = &source;
    state_.extractor = AMediaExtractor_new();

    if (!state_.extractor)
    {
        LOGE("Failed to create extractor.");
        return false;
    }

    media_status_t status =
        AMediaExtractor_setDataSourceFd(
            state_.extractor,
            source_->fileDescriptor(),
            source_->startOffset(),
            source_->length());

    if (status != AMEDIA_OK)
    {
        LOGE("Failed to set extractor data source.");
        return false;
    }


    return true;
}

const ExtractorState &ExtractorController::state() const
{
    return state_;
}

bool ExtractorController::readMetaData()
{
    size_t trackCount = AMediaExtractor_getTrackCount(
        state_.extractor);


    for (size_t i = 0; i < trackCount; i++)
    {
        AMediaFormat *format = AMediaExtractor_getTrackFormat(
            state_.extractor,
            i);
        if (!format)
        {
            continue;
        }

        const char *mime = nullptr;

        AMediaFormat_getString(
            format, AMEDIAFORMAT_KEY_MIME,
            &mime);

        if (mime && strncmp(mime, "audio/", 6) == 0)
        {
            state_.trackIndex = i;
            state_.format = format;

            AMediaExtractor_selectTrack(
                state_.extractor,
                i);

            break;
        }
    }

    if (!state_.format)
    {
        LOGE("No audio track found.");

        return false;
    }

    AMediaFormat_getInt32(
        state_.format,
        AMEDIAFORMAT_KEY_SAMPLE_RATE,
        &state_.sampleRate);

    AMediaFormat_getInt32(
        state_.format,
        AMEDIAFORMAT_KEY_CHANNEL_COUNT,
        &state_.channelCount);

    AMediaFormat_getInt32(
        state_.format,
        AMEDIAFORMAT_KEY_BIT_RATE,
        &state_.bitRate);

    AMediaFormat_getInt64(
        state_.format,
        AMEDIAFORMAT_KEY_DURATION,
        &state_.durationUs);





    return true;
}

ExtractorController::~ExtractorController()
{
    close();
}

void ExtractorController::close()
{
    if (state_.format)
    {
        AMediaFormat_delete(state_.format);
        state_.format = nullptr;
    }

    if (state_.extractor)
    {
        AMediaExtractor_delete(state_.extractor);
        state_.extractor = nullptr;
    }

    source_ = nullptr;

}

bool ExtractorController::seek(int64_t positionUs)
{
    if (!state_.extractor)
    {
        return false;
    }

    media_status_t status =
        AMediaExtractor_seekTo(
            state_.extractor,
            positionUs,
            AMEDIAEXTRACTOR_SEEK_CLOSEST_SYNC);

    if (status != AMEDIA_OK)
    {
        LOGE("Failed to seek extractor");
        return false;
    }

    return true;
}

int ExtractorController::sampleRate() const
{
    return state_.sampleRate;
}

int ExtractorController::channelCount() const
{
    return state_.channelCount;
}

int ExtractorController::bitRate() const
{
    return state_.bitRate;
}

int64_t ExtractorController::durationUs() const
{
    return state_.durationUs;
}