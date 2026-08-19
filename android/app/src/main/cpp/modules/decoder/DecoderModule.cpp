#include "DecoderModule.h"

#include "../../context/EngineContext.h"
#include "../../datasource/FileDataSource.h"
#include "../../datasource/ContentDataSource.h"

#include "../../common/Logger.h"

bool DecoderModule::initialize(EngineContext &)
{
    LOGI("DecoderModule initialized.");
    playback_.initialize(decoder_);
    return true;
}

bool DecoderModule::loadTrack(const std::string &path)
{
    LOGI("Loading track:");
    LOGI("%s", path.c_str());

    source_.reset();

    if (path.rfind("content://", 0) == 0)
    {
        source_ = std::make_unique<ContentDataSource>();
    }
    else
    {
        source_ = std::make_unique<FileDataSource>();
    }

    if (!source_->open(path))
    {
        LOGE("Failed to open file.");
        return false;
    }

    return decoder_.open(*source_);
}

void DecoderModule::initializePlaybackSession()
{
    metadata_.sampleRate =
        decoder_.sampleRate();

    metadata_.channels =
        decoder_.channelCount();

    metadata_.bitRate =
        decoder_.bitRate();

    metadata_.durationUs =
        decoder_.durationUs();

    playbackState_.reset();

    playback_.clear();

    playback_.start();
}

void DecoderModule::shutdown()
{
    LOGI("DecoderModule shutdown.");
}

PlaybackSnapshot DecoderModule::playbackSnapshot() const
{
    return PlaybackClock::snapshot(metadata_, playbackState_);
}