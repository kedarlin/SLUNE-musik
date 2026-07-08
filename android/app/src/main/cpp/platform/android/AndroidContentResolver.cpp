#include "AndroidContentResolver.h"

#include "../../common/Logger.h"
#include "AndroidContext.h"
#include "JniUtils.h"

ContentResolverResult
AndroidContentResolver::openFileDescriptor(
    const std::string &uriString)
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

    // -------------------------------------------------------------------------
    // android.net.Uri
    // -------------------------------------------------------------------------

    jclass uriClass =
        env->FindClass("android/net/Uri");

    if (!uriClass)
    {
        result.error = "Failed to find android.net.Uri";
        return result;
    }

    jmethodID parseMethod =
        env->GetStaticMethodID(
            uriClass,
            "parse",
            "(Ljava/lang/String;)Landroid/net/Uri;");

    if (!parseMethod)
    {
        result.error = "Failed to find Uri.parse()";
        return result;
    }

    jstring uri =
        env->NewStringUTF(uriString.c_str());

    jobject uriObject =
        env->CallStaticObjectMethod(
            uriClass,
            parseMethod,
            uri);

    if (env->ExceptionCheck())
    {
        env->ExceptionDescribe();
        env->ExceptionClear();

        result.error = "Uri.parse() threw an exception.";
        return result;
    }

    if (!uriObject)
    {
        result.error = "Failed to create Uri object.";
        return result;
    }

    // -------------------------------------------------------------------------
    // ContentResolver
    // -------------------------------------------------------------------------

    jclass contextClass =
        env->GetObjectClass(context);

    jmethodID resolverMethod =
        env->GetMethodID(
            contextClass,
            "getContentResolver",
            "()Landroid/content/ContentResolver;");

    if (!resolverMethod)
    {
        result.error = "Failed to find getContentResolver().";
        return result;
    }

    jobject resolver =
        env->CallObjectMethod(
            context,
            resolverMethod);

    if (env->ExceptionCheck())
    {
        env->ExceptionDescribe();
        env->ExceptionClear();

        result.error = "getContentResolver() threw an exception.";
        return result;
    }

    if (!resolver)
    {
        result.error = "ContentResolver is null.";
        return result;
    }

    // -------------------------------------------------------------------------
    // openFileDescriptor()
    // -------------------------------------------------------------------------

    jclass resolverClass =
        env->GetObjectClass(resolver);

    jmethodID openMethod =
        env->GetMethodID(
            resolverClass,
            "openFileDescriptor",
            "(Landroid/net/Uri;Ljava/lang/String;)Landroid/os/ParcelFileDescriptor;");

    if (!openMethod)
    {
        result.error = "Failed to find openFileDescriptor().";
        return result;
    }

    jstring mode =
        env->NewStringUTF("r");

    jobject pfd =
        env->CallObjectMethod(
            resolver,
            openMethod,
            uriObject,
            mode);

    if (env->ExceptionCheck())
    {
        env->ExceptionDescribe();
        env->ExceptionClear();

        result.error = "openFileDescriptor() threw an exception.";
        return result;
    }

    if (!pfd)
    {
        result.error = "ParcelFileDescriptor is null.";
        return result;
    }

    // -------------------------------------------------------------------------
    // detachFd()
    // -------------------------------------------------------------------------

    jclass pfdClass =
        env->GetObjectClass(pfd);

    jmethodID detachMethod =
        env->GetMethodID(
            pfdClass,
            "detachFd",
            "()I");

    if (!detachMethod)
    {
        result.error = "Failed to find detachFd().";
        return result;
    }

    jint fd =
        env->CallIntMethod(
            pfd,
            detachMethod);

    if (env->ExceptionCheck())
    {
        env->ExceptionDescribe();
        env->ExceptionClear();

        result.error = "detachFd() threw an exception.";
        return result;
    }

    if (fd < 0)
    {
        result.error = "detachFd() returned an invalid file descriptor.";
        return result;
    }

    result.fileDescriptor = fd;

    LOGI("Content URI opened successfully.");

    // -------------------------------------------------------------------------
    // Cleanup
    // -------------------------------------------------------------------------

    env->DeleteLocalRef(uri);
    env->DeleteLocalRef(uriObject);
    env->DeleteLocalRef(uriClass);

    env->DeleteLocalRef(mode);

    env->DeleteLocalRef(contextClass);

    env->DeleteLocalRef(resolver);
    env->DeleteLocalRef(resolverClass);

    env->DeleteLocalRef(pfd);
    env->DeleteLocalRef(pfdClass);

    return result;
}