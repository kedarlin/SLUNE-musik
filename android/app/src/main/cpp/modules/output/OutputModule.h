#pragma once

#include "../base/IAudioModule.h"

class OutputModule : public IAudioModule
{
public:
    bool initialize(EngineContext &context) override;
    void shutdown() override;
};