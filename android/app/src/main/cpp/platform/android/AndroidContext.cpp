#include "AndroidContext.h"

AndroidContext &AndroidContext::instance()
{
    static AndroidContext context;
    return context;
}

void AndroidContext::initialize(JavaVM *vm)
{
    vm_ = vm;
}

void AndroidContext::setApplicationContext(
    JNIEnv *env,
    jobject context)
{
    if (applicationContext_ != nullptr)
    {
        env->DeleteGlobalRef(applicationContext_);
        applicationContext_ = nullptr;
    }

    applicationContext_ = env->NewGlobalRef(context);

}

JavaVM *AndroidContext::javaVm() const
{
    return vm_;
}

jobject AndroidContext::applicationContext() const
{
    return applicationContext_;
}