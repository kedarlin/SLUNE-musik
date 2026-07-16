#pragma once

#include "../base/IAudioModule.h"
#include "../../decoder/MediaCodecDecoder.h"
#include "../../datasource/FileDataSource.h"
#include "../../playback/PlaybackController.h"

#include <string>
#include <memory>

class DecoderModule : public IAudioModule
{
public:
    bool initialize(EngineContext &context) override;

    bool loadTrack(const std::string &path);

    void shutdown() override;

    MediaCodecDecoder &decoder()
    {
        return decoder_;
    }

    PlaybackController &playback()
    {
        return playback_;
    }

private:
    std::unique_ptr<IDataSource> source_;
    MediaCodecDecoder decoder_;
    PlaybackController playback_;
};