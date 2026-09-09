#include "AudioEngine.h"

#include "../common/Logger.h"
#include "../pipeline/source/TrackSourceNode.h"

AudioEngine::AudioEngine()
    : context_(std::make_unique<EngineContext>())
{
}

PlaybackSnapshot AudioEngine::playbackSnapshot() const
{
    return decoder_.playbackSnapshot();
}

bool AudioEngine::isPlaying() const
{
    return context_->playing.load(std::memory_order_acquire);
}

AudioEngine::~AudioEngine()
{
    release();
}

bool AudioEngine::initialize()
{
    if (context_->initialized)
    {
        return true;
    }

    context_->initialized = true;

    decoder_.initialize(*context_);
    output_.initialize(*context_);
    dsp_.initialize(*context_);


    output_.pipeline().setSource(std::make_unique<TrackSourceNode>(
        decoder_.playback()));

    return true;
}

bool AudioEngine::loadTrack(const std::string &path)
{
    if (!context_->initialized)
    {
        LOGE("Engine not initialized");

        return false;
    }

    bool success = decoder_.loadTrack(path);

    if (!success)
    {
        return false;
    }
    decoder_.initializePlaybackSession();

    decoder_.playback().clear();
    decoder_.playback().start();


    return success;
}

void AudioEngine::play()
{
    if (!context_->initialized)
    {
        return;
    }

    context_->playing = true;

}

oboe::Result AudioEngine::setSpeed(float speed)
{
    decoder_.setPlaybackSpeed(speed);

    return oboe::Result::OK;
}

oboe::Result AudioEngine::setPitch(float pitch)
{
    decoder_.setPlaybackPitch(pitch);

    return oboe::Result::OK;
}

void AudioEngine::setVolume(float volume)
{
    context_->volume.store(
        volume < 0.0f ? 0.0f : (volume > 1.0f ? 1.0f : volume),
        std::memory_order_relaxed);
}

void AudioEngine::pause()
{
    if (!context_->initialized)
    {
        return;
    }

    context_->playing = false;

}

ProcessResult AudioEngine::seek(int64_t positionUs)
{
    // positionUs is in effective (speed-scaled) playback time, matching what
    // engine_get_position_seconds()/engine_get_duration_seconds() report.
    // Convert back to media time before it reaches the decoder, which only
    // understands media time.
    const float speed = decoder_.playbackSnapshot().playbackSpeed;
    const float effectiveSpeed = speed > 0.0f ? speed : 1.0f;

    const auto mediaPositionUs =
        static_cast<int64_t>(static_cast<double>(positionUs) * effectiveSpeed);

    return decoder_.seek(mediaPositionUs);
}

void AudioEngine::release()
{
    if (!context_->initialized)
    {
        return;
    }

    context_->playing = false;

    decoder_.playback().stop();
    decoder_.playback().clear();

    context_->initialized = false;

    dsp_.shutdown();
    output_.shutdown();
    decoder_.shutdown();

}