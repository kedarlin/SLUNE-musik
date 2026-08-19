#pragma once

#include "../../datasource/IDataSource.h"
#include "../../platform/android/ExtractorState.h"

class ExtractorController
{
public:
    ExtractorController() = default;
    ~ExtractorController();

    bool open(IDataSource &source);
    bool readMetaData();
    bool seek(int64_t positionMs);
    void close();
    const ExtractorState &state() const;
    int sampleRate() const;
    int channelCount() const;
    int bitRate() const;
    int64_t durationUs() const;

private:
    IDataSource *source_ = nullptr;
    ExtractorState state_;
};