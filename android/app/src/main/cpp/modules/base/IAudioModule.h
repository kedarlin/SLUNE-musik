#pragma once

class EngineContext;

class IAudioModule
{
public:
    virtual ~IAudioModule() = default;
    virtual bool initialize(EngineContext &context) = 0;
    virtual void shutdown() = 0;
};