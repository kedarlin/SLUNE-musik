#include "AudioEngine.h"

#include "../common/Logger.h"

AudioEngine::AudioEngine()
    : context_(std::make_unique<EngineContext>())
{
}

AudioEngine::~AudioEngine()
{
    release();
}

bool AudioEngine::initialize()
{
    if (context_->initialized)
    {
        LOGI("Engine already initialized.");
        return true;
    }

    context_->initialized = true;

    decoder_.initialize(*context_);
    output_.initialize(*context_);
    dsp_.initialize(*context_);

    LOGI("Engine initialized.");

    return true;
}

void AudioEngine::play()
{
    if (!context_->initialized)
    {
        LOGI("Cannot play. Engine not initialized.");
        return;
    }

    context_->playing = true;

    LOGI("Playback started.");
}

void AudioEngine::pause()
{
    if (!context_->initialized)
    {
        return;
    }

    context_->playing = false;

    LOGI("Playback paused.");
}

void AudioEngine::release()
{
    if (!context_->initialized)
    {
        return;
    }

    context_->playing = false;
    context_->initialized = false;

    dsp_.shutdown();
    output_.shutdown();
    decoder_.shutdown();

    LOGI("Engine released.");
}