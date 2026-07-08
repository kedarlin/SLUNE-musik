#pragma once

#include "ContentResolverResult.h"

#include <string>

class AndroidContentResolver
{
public:
    static ContentResolverResult openFileDescriptor(
        const std::string &uri);
};