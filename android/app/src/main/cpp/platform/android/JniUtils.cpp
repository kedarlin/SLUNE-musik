#include "JniUtils.h"
#include "AndroidContext.h"

JNIEnv *JniUtils::getEnv()
{
    JavaVM *vm = AndroidContext::instance().javaVm();

    if (!vm)
    {
        return nullptr;
    }

    JNIEnv *env = nullptr;

    jint result = vm->GetEnv(
        reinterpret_cast<void **>(&env),
        JNI_VERSION_1_6);

    if (result == JNI_EDETACHED)
    {
        if (vm->AttachCurrentThread(&env, nullptr) != JNI_OK)
        {
            return nullptr;
        }
    }

    return env;
}