#pragma once

#include "../base/IAudioModule.h"
#include "../../output/OboeOutput.h"

class OutputModule : public IAudioModule
{
public:
    bool initialize(EngineContext &context) override;
    void shutdown() override;

private:
    OboeOutput output_;
};