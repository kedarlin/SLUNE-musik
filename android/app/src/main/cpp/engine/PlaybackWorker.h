#pragma once

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <thread>

class PlaybackController;

class PlaybackWorker
{
public:
    PlaybackWorker();
    ~PlaybackWorker();

    bool start(PlaybackController &controller);
    void stop();
    void requestFill();

private:
    void workerLoop();

private:
    PlaybackController *controller_ = nullptr;
    std::thread thread_;
    std::atomic<bool> running_{false};
    std::atomic<bool> stopRequested_{false};
    std::mutex mutex_;
    std::condition_variable condition_;
    std::atomic<bool> wakeRequested_{false};
};