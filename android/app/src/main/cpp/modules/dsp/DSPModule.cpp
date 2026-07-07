#include "DSPModule.h"

#include "../../context/EngineContext.h"

#include "../../common/Logger.h"

bool DSPModule::initialize(EngineContext &)
{
    LOGI("DSPModule intiialized.");
    return true;
}

void DSPModule::shutdown()
{
    LOGI("DSPModule shutdown.");
}