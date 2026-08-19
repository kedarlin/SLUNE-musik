#pragma once

#include "../modules/decoder/DecoderModule.h"
#include "../modules/dsp/DSPModule.h"
#include "../modules/output/OutputModule.h"
#include "playback/PlaybackMetadata.h"
#include "playback/PlaybackState.h"

#include <memory>
#include <string>

#include "../context/EngineContext.h"

class AudioEngine
{
public:
    AudioEngine();
    ~AudioEngine();

    bool initialize();

    bool loadTrack(const std::string &path);

    void play();

    void pause();

    ProcessResult seek(int64_t positionUs);

    void release();

    PlaybackSnapshot playbackSnapshot() const;

private:
    std::unique_ptr<EngineContext> context_;
    DecoderModule decoder_;
    OutputModule output_;
    DSPModule dsp_;
};