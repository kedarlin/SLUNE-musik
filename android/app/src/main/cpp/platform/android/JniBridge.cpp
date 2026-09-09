#include <jni.h>

#include "AndroidContext.h"

JNIEXPORT jint JNICALL
JNI_OnlLoad(JavaVM *vm, void *reserved)
{

    AndroidContext::instance().initialize(vm);

    return JNI_VERSION_1_6;
}