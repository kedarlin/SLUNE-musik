#pragma once

#include <memory>

#include <oboe/Oboe.h>

class OboeOutput
{
    public:
    OboeOutput();
    ~OboeOutput();

    bool initialize();

    void shutdown();

private:
    std::shared_ptr<oboe::AudioStream> stream_;
};