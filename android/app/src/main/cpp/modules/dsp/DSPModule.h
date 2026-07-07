#pragma once

#include "../base/IAudioModule.h"

class DSPModule : public IAudioModule
{
public:
    bool initialize(EngineContext &context) override;

    void shutdown() override;
};