#pragma once

#include "Idecoder.h"

class MedaiCodecDecoder : public IDecoder
{
    public:
    bool open(const std::string& filePath) override;
    void close() override;
    ProcessResult decode(AudioBuffer& buffer) override;
    bool seek(int64_t positionMs) override;
};