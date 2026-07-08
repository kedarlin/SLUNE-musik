#include <jni.h>

#include "AndroidContext.h"
#include "../../common/Logger.h"

JNIEXPORT jint JNICALL
JNI_OnlLoad(JavaVM *vm, void *reserved)
{
    LOGI("JNI_OnLoad called");

    AndroidContext::instance().initialize(vm);

    return JNI_VERSION_1_6;
}