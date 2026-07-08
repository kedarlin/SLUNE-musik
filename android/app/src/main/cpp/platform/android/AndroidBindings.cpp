#include <jni.h>

#include "AndroidContext.h"

#include "../../common/Logger.h"

extern "C" JNIEXPORT void JNICALL
Java_com_example_music_NativeBridge_nativeInitializeAndroid(
    JNIEnv *env,
    jobject /*thiz*/,
    jobject context)
{

    LOGI("nativeInitializeAndroid called");

    JavaVM *vm = nullptr;
    env->GetJavaVM(&vm);

    AndroidContext::instance().initialize(vm);
    AndroidContext::instance().setApplicationContext(env, context);

    LOGI("Android platform initialized.");
}