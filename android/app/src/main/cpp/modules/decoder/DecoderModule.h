#pragma once

#include "../base/IAudioModule.h"
#include "../../decoder/MediaCodecDecoder.h"
#include "../../datasource/FileDataSource.h"
#include "../../playback/PlaybackController.h"
#include "../../engine/playback/PlaybackClock.h"
#include "../../engine/playback/PlaybackMetadata.h"

#include <string>
#include <memory>

class DecoderModule : public IAudioModule
{
public:
    bool initialize(EngineContext &context) override;

    bool loadTrack(const std::string &path);

    ProcessResult seek(int64_t positionUs);

    void shutdown() override;

    void initializePlaybackSession();

    PlaybackSnapshot playbackSnapshot() const;

    MediaCodecDecoder &decoder()
    {
        return decoder_;
    }

    int sampleRate() const
    {
        return decoder_.sampleRate();
    }

    int channelCount() const
    {
        return decoder_.channelCount();
    }

    int bitRate() const
    {
        return decoder_.bitRate();
    }

    int64_t durationUs() const
    {
        return decoder_.durationUs();
    }

    PlaybackController &playback()
    {
        return playback_;
    }

private:
    std::unique_ptr<IDataSource> source_;
    MediaCodecDecoder decoder_;
    PlaybackMetadata metadata_;
    PlaybackState playbackState_;
    PlaybackController playback_{decoder_, playbackState_};
};