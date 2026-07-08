#include "CodecController.h"

#include "../../common/Logger.h"

CodecController::~CodecController()
{
    close();
}

bool CodecController::initialize(
    const ExtractorState &extractor)
{
    const char *mime = nullptr;

    if (!AMediaFormat_getString(
            extractor.format,
            AMEDIAFORMAT_KEY_MIME,
            &mime))
    {
        LOGE("Failed to get MIME type.");

        return false;
    }

    LOGI("Creating codec for: %s", mime);

    state_.codec =
        AMediaCodec_createDecoderByType(mime);

    if (!state_.codec)
    {
        LOGE("Failed to create codec.");

        return false;
    }

    LOGI("Codec created.");

    media_status_t status =
        AMediaCodec_configure(
            state_.codec,
            extractor.format,
            nullptr,
            nullptr,
            0);

    if (status != AMEDIA_OK)
    {
        LOGE("Failed to configure codec.");

        return false;
    }

    state_.configured = true;

    LOGI("Codec configured.");

    status =
        AMediaCodec_start(
            state_.codec);

    if (status != AMEDIA_OK)
    {
        LOGE("Failed to start codec.");

        return false;
    }

    state_.started = true;

    LOGI("Codec started.");

    return true;
}

ProcessResult CodecController::decode(AudioBuffer &)
{
    return ProcessResult::NoData;
}

void CodecController::flush()
{
    LOGI("CodecController flush");
}

void CodecController::close()
{
    if (state_.codec)
    {
        if (state_.started)
        {
            AMediaCodec_stop(state_.codec);
        }
        AMediaCodec_delete(state_.codec);

        state_.codec = nullptr;
    }

    state_.configured = false;
    state_.started = false;

    LOGI("CodecController closed.");
}
