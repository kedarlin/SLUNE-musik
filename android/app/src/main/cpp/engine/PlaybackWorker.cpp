#include "PlaybackWorker.h"

#include "../playback/PlaybackController.h"

#include "../common/Logger.h"

#include <chrono>

PlaybackWorker::PlaybackWorker() = default;

PlaybackWorker::~PlaybackWorker()
{
    stop();
}

bool PlaybackWorker::start(PlaybackController &controller)
{
    if (running_)
    {
        return true;
    }

    controller_ = &controller;

    stopRequested_ = false;

    running_ = true;

    thread_ = std::thread(&PlaybackWorker::workerLoop, this);

    LOGI("PlaybackWorker started.");

    return true;
}

void PlaybackWorker::stop()
{
    if (!running_)
    {
        return;
    }

    stopRequested_ = true;

    if (thread_.joinable())
    {
        thread_.join();
    }

    running_ = false;
    LOGI("PlaybackWOrker stoped.");
}

void PlaybackWorker::workerLoop()
{
    while (!stopRequested_)
    {
        controller_->fillFifo();

        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
}