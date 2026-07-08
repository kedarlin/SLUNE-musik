#pragma once

#include "../base/IAudioModule.h"
#include "../../decoder/MediaCodecDecoder.h"
#include "../../datasource/FileDataSource.h"

#include <string>

class DecoderModule : public IAudioModule
{
public:
    bool initialize(EngineContext &context) override;

    bool loadTrack(const std::string &path);

    void shutdown() override;

private:
    std::unique_ptr<IDataSource> source_;
    MediaCodecDecoder decoder_;
};