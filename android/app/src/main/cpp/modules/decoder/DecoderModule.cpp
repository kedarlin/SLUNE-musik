#include "DecoderModule.h"

#include "../../context/EngineContext.h"

#include <android/log.h>

#define TAG "MuxicEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

bool DecoderModule::initialize(EngineContext &)
{
    LOGI("DecoderModule initialized.");
    return true;
}

void DecoderModule::shutdown()
{
    LOGI("DecoderModule shutdown.");
}