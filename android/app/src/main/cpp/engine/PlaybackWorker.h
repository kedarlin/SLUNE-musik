#pragma once

#include <atomic>
#include <thread>

class PlaybackController;

class PlaybackWorker
{
public:
    PlaybackWorker();
    ~PlaybackWorker();

    bool start(PlaybackController &controller);
    void stop();

private:
    void workerLoop();

private:
    PlaybackController *controller_ = nullptr;
    std::thread thread_;
    std::atomic<bool> running_{false};
    std::atomic<bool> stopRequested_{false};
};