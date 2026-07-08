#include "AndroidContentResolver.h"

#include "../../common/Logger.h"
#include "AndroidContext.h"
#include "JniUtils.h"

ContentResolverResult
AndroidContentResolver::openFileDescriptor(
    const std::string &uri)
{
    ContentResolverResult result;

    JNIEnv *env = JniUtils::getEnv();

    if (!env)
    {
        result.error = "JNIEnv unavailable";
        return result;
    }

    jobject context =
        AndroidContext::instance().applicationContext();

    if (!context)
    {
        result.error = "Application context unavailable";
        return result;
    }

    LOGI("AndroidContentResolver reached successfully.");

    return result;
}