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


    state_.codec =
        AMediaCodec_createDecoderByType(mime);

    if (!state_.codec)
    {
        LOGE("Failed to create codec.");

        return false;
    }


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


    status =
        AMediaCodec_start(
            state_.codec);

    if (status != AMEDIA_OK)
    {
        LOGE("Failed to start codec.");

        return false;
    }

    state_.started = true;


    return true;
}

ProcessResult CodecController::decode(const ExtractorState &extractor, AudioBuffer &buffer)
{
    if (!queueInputBuffer(extractor))
    {
        if (state_.endOfStream)
        {
            // The extractor is exhausted, but the codec may still be
            // holding buffered output frames from before EOS was queued -
            // keep draining until it reports no more data.
            const ProcessResult drainResult =
                dequeueOutputBuffer(extractor, buffer);

            if (drainResult == ProcessResult::Continue)
            {
                return ProcessResult::Continue;
            }

            return ProcessResult::EndOfStream;
        }

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


    AMediaExtractor_advance(extractor.extractor);


    return true;
}

ProcessResult CodecController::dequeueOutputBuffer(
    const ExtractorState &extractor,
    AudioBuffer &buffer)
{

    buffers_.outputIndex =
        AMediaCodec_dequeueOutputBuffer(
            state_.codec,
            &buffers_.bufferInfo,
            0);


    switch (buffers_.outputIndex)
    {
    case AMEDIACODEC_INFO_TRY_AGAIN_LATER:
        return ProcessResult::NoData;

    case AMEDIACODEC_INFO_OUTPUT_FORMAT_CHANGED:
        return ProcessResult::NoData;

    case AMEDIACODEC_INFO_OUTPUT_BUFFERS_CHANGED:
        return ProcessResult::NoData;

    default:
        break;
    }

    if (buffers_.outputIndex < 0)
    {
        LOGE("Invalid output buffer index.");

        return ProcessResult::NoData;
    }

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



    if (buffers_.bufferInfo.size == 0)
    {

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


    pcmBuffer_.resize(sampleCount);

    std::memcpy(
        pcmBuffer_.data(),
        outputBuffer,
        buffers_.bufferInfo.size);


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
    if (state_.codec)
    {
        AMediaCodec_flush(state_.codec);
    }

    state_.endOfStream = false;

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

}
