#pragma once

#include <jni.h>

class JniUtils
{
public:
    static JNIEnv* getEnv();
};