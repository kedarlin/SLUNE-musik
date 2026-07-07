#include "OutputModule.h"

#include "../../context/EngineContext.h"

#include "../../common/Logger.h"

bool OutputModule::initialize(EngineContext &)
{
    LOGI("OutoutModule initialized.");
    return output_.initialize();
}

void OutputModule::shutdown()
{
    output_.shutdown();
    LOGI("OutputModule shutdown.");
}