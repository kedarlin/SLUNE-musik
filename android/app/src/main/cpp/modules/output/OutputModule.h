#pragma once

#include "../base/IAudioModule.h"
#include "../../output/OboeOutput.h"

class OutputModule : public IAudioModule
{
public:
    bool initialize(EngineContext &context) override;
    AudioPipeline &pipeline();
    void shutdown() override;

private:
    AudioPipeline pipeline_;
    OboeOutput output_;
};