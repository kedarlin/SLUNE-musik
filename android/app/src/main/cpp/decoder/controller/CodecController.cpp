#include "CodecController.h"
#include "../../common/Logger.h"

#include <cstring>
#include <media/NdkMediaCodec.h>

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

ProcessResult CodecController::decode(const ExtractorState &extractor, AudioBuffer &buffer)
{
    static bool logged = false;
    if (!logged)
    {

        LOGI("CodecController::decode()");
        logged = true;
    }
    if (!queueInputBuffer(extractor))
    {
        return ProcessResult::NoData;
    }

    return dequeueOutputBuffer(extractor, buffer);
}

bool CodecController::queueInputBuffer(
    const ExtractorState &extractor)
{
    buffers_.inputIndex = AMediaCodec_dequeueInputBuffer(
        state_.codec,
        0);

    if (buffers_.inputIndex < 0)
    {
        return false;
    }

    LOGI("Input buffer index: %zd", buffers_.inputIndex);

    size_t bufferSize = 0;

    uint8_t *inputBuffer = AMediaCodec_getInputBuffer(
        state_.codec,
        buffers_.inputIndex,
        &bufferSize);

    if (!inputBuffer)
    {
        LOGE("Failed to get codec input buffer.");

        return false;
    }

    ssize_t sampleSize = AMediaExtractor_readSampleData(extractor.extractor, inputBuffer, bufferSize);

    if (sampleSize < 0)
    {
        LOGI("End of stream.");

        AMediaCodec_queueInputBuffer(
            state_.codec,
            buffers_.inputIndex,
            0, 0, 0, AMEDIACODEC_BUFFER_FLAG_END_OF_STREAM);

        state_.endOfStream = true;

        return false;
    }

    int64_t presentationTime = AMediaExtractor_getSampleTime(extractor.extractor);

    media_status_t status = AMediaCodec_queueInputBuffer(
        state_.codec,
        buffers_.inputIndex,
        0,
        sampleSize,
        presentationTime,
        0);

    if (status != AMEDIA_OK)
    {
        LOGE("Failed to queue input buffer.");

        return false;
    }

    LOGI("Queued %zd bytes.", sampleSize);

    AMediaExtractor_advance(extractor.extractor);

    LOGI("Extractor advanced.");

    return true;
}

ProcessResult CodecController::dequeueOutputBuffer(
    const ExtractorState &extractor,
    AudioBuffer &buffer)
{
    LOGI("dequeueOutputBuffer()");

    buffers_.outputIndex =
        AMediaCodec_dequeueOutputBuffer(
            state_.codec,
            &buffers_.bufferInfo,
            0);

    LOGI("Output buffer index: %zd", buffers_.outputIndex);

    switch (buffers_.outputIndex)
    {
    case AMEDIACODEC_INFO_TRY_AGAIN_LATER:
        LOGI("TRY_AGAIN_LATER");
        return ProcessResult::NoData;

    case AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED:
        LOGI("OUTPUT_FORMAT_CHANGED");
        return ProcessResult::NoData;

    case AMEDIACODEC_INFO_OUTPUT_BUFFERS_CHANGED:
        LOGI("OUTPUT_BUFFERS_CHANGED");
        return ProcessResult::NoData;

    default:
        break;
    }

    if (buffers_.outputIndex < 0)
    {
        LOGE("Invalid output buffer index.");

        return ProcessResult::NoData;
    }

    // AMediaFormat *format =
    //     AMediaCodec_getOutputFormat(state_.codec);

    // int32_t sampleRate = 0;
    // int32_t channels = 0;
    // int32_t pcmEncoding = 0;

    // AMediaFormat_getInt32(
    //     format,
    //     AMEDIAFORMAT_KEY_SAMPLE_RATE,
    //     &sampleRate);

    // AMediaFormat_getInt32(
    //     format,
    //     AMEDIAFORMAT_KEY_CHANNEL_COUNT,
    //     &channels);

    // AMediaFormat_getInt32(
    //     format,
    //     AMEDIAFORMAT_KEY_PCM_ENCODING,
    //     &pcmEncoding);

    // LOGI(
    //     "Codec Output: %d Hz, %d channels, PCM encoding %d",
    //     sampleRate,
    //     channels,
    //     pcmEncoding);

    size_t outputBufferSize = 0;

    uint8_t *outputBuffer =
        AMediaCodec_getOutputBuffer(
            state_.codec,
            buffers_.outputIndex,
            &outputBufferSize);

    if (!outputBuffer)
    {
        LOGE("Failed to get output buffer.");

        AMediaCodec_releaseOutputBuffer(
            state_.codec,
            buffers_.outputIndex,
            false);

        return ProcessResult::NoData;
    }

    LOGI(
        "PCM Size: %d  Offset: %d  Flags: %d  Time: %lld",
        buffers_.bufferInfo.size,
        buffers_.bufferInfo.offset,
        buffers_.bufferInfo.flags,
        (long long)buffers_.bufferInfo.presentationTimeUs);

    LOGI(
        "Decoded %d bytes.",
        buffers_.bufferInfo.size);

    if (buffers_.bufferInfo.size == 0)
    {
        LOGI("Empty PCM buffer.");

        AMediaCodec_releaseOutputBuffer(
            state_.codec,
            buffers_.outputIndex,
            false);

        return ProcessResult::NoData;
    }

    int32_t sampleCount =
        buffers_.bufferInfo.size /
        sizeof(int16_t);

    int32_t frameCount =
        sampleCount /
        extractor.channelCount;

    LOGI(
        "Frames: %d  Samples: %d",
        frameCount,
        sampleCount);

    pcmBuffer_.resize(sampleCount);

    std::memcpy(
        pcmBuffer_.data(),
        outputBuffer,
        buffers_.bufferInfo.size);

    LOGI(
        "Copied %zu PCM bytes into engine buffer.",
        pcmBuffer_.size());

    const int16_t *pcm =
        reinterpret_cast<const int16_t *>(
            pcmBuffer_.data());

    buffer.setData(
        pcmBuffer_.data(),
        frameCount,
        extractor.channelCount,
        static_cast<float>(extractor.sampleRate),
        SampleFormat::Int16);

    AMediaCodec_releaseOutputBuffer(
        state_.codec,
        buffers_.outputIndex,
        false);

    return ProcessResult::Continue;
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
    buffers_ = {};

    LOGI("CodecController closed.");
}
