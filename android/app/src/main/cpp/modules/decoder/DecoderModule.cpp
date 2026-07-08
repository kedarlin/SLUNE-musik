#include "DecoderModule.h"

#include "../../context/EngineContext.h"
#include "../../datasource/FileDataSource.h"
#include "../../datasource/ContentDataSource.h"

#include "../../common/Logger.h"

bool DecoderModule::initialize(EngineContext &)
{
    LOGI("DecoderModule initialized.");
    return true;
}

bool DecoderModule::loadTrack(const std::string &path)
{
    LOGI("Loading track:");
    LOGI("%s", path.c_str());

    source_.reset();

    if (path.rfind("content://", 0) == 0)
    {
        source_ = std::make_unique<ContentDataSource>();
    }
    else
    {
        source_ = std::make_unique<FileDataSource>();
    }

    if (!source_->open(path))
    {
        LOGE("Failed to open file.");
        return false;
    }

    return decoder_.open(*source_);
}

void DecoderModule::shutdown()
{
    LOGI("DecoderModule shutdown.");
}