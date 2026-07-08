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

private:
    IDataSource *source_ = nullptr;
    ExtractorState state_;
};