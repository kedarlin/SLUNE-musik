#pragma once

#include "../base/IAudioModule.h"

class DecoderModule : public IAudioModule
{
public:
    bool initialize(EngineContext& context) override;

    void shutdown() override;
};