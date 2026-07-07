#include "OutputModule.h"

#include "../../context/EngineContext.h"

#include <android/log.h>

#define TAG "MuxicEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

bool OutputModule::initialize(EngineContext&)
{
    LOGI("OutoutModule initialized.");
    return true;
}

void OutputModule::shutdown()
{
    LOGI("OutputModule shutdown.");
}