#pragma once

#include <jni.h>

class AndroidContext
{
public:
    static AndroidContext &instance();

    void initialize(JavaVM *vm);
    void setApplicationContext(JNIEnv *env, jobject context);
    JavaVM *javaVm() const;
    jobject applicationContext() const;

private:
    AndroidContext() = default;
    JavaVM *vm_ = nullptr;
    jobject applicationContext_ = nullptr;
};