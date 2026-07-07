#include "DecoderModule.h"

#include "../../context/EngineContext.h"

#include "../../common/Logger.h"

bool DecoderModule::initialize(EngineContext &)
{
    LOGI("DecoderModule initialized.");
    return true;
}

void DecoderModule::shutdown()
{
    LOGI("DecoderModule shutdown.");
}