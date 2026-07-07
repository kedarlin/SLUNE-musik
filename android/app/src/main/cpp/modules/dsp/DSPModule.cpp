#include "DSPModule.h"

#include "../../context/EngineContext.h"

#include <android/log.h>

#define TAG "MuxicEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

bool DSPModule::initialize(EngineContext &)
{
    LOGI("DSPModule intiialized.");
    return true;
}

void DSPModule::shutdown()
{
    LOGI("DSPModule shutdown.");
}