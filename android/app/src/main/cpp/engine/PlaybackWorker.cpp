#include "PlaybackWorker.h"

#include "../playback/PlaybackController.h"

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

    return true;
}

void PlaybackWorker::stop()
{
    if (!running_)
    {
        return;
    }

    stopRequested_ = true;

    condition_.notify_one();

    if (thread_.joinable())
    {
        thread_.join();
    }

    running_ = false;
}

void PlaybackWorker::workerLoop()
{
    while (!stopRequested_)
    {
        std::unique_lock<std::mutex> lock(mutex_);

        condition_.wait(
            lock,
            [this]
            {
                return wakeRequested_ || stopRequested_;
            });
        if (stopRequested_)
        {
            break;
        }
        wakeRequested_.store(false, std::memory_order_release);
        lock.unlock();

        controller_->fillFifo();
    }
}

void PlaybackWorker::requestFill()
{
    bool expected = false;

    if (!wakeRequested_.compare_exchange_strong(
            expected,
            true))
    {
        return;
    }

    condition_.notify_one();
}