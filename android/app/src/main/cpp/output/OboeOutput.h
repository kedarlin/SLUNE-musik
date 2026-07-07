#pragma once

#include "AudioCallback.h"

#include <memory>
#include <oboe/Oboe.h>

class OboeOutput
{
public:
    OboeOutput();
    ~OboeOutput();

    bool initialize(EngineContext &context);
    void shutdown();

private:
    std::shared_ptr<oboe::AudioStream> stream_;
    std::unique_ptr<AudioCallback> callback_;
};