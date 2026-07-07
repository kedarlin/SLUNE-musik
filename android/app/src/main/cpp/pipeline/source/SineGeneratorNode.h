#pragma once

#include "AudioSourceNode.h"
#include "../ProcessResult.h"

class SineGeneratorNode : public AudioSourceNode
{
public:
    ProcessResult process(
        AudioBuffer &buffer) override;

private:
    float phase_ = 0.0f;
};