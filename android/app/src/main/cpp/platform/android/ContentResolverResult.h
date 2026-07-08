#pragma once

#include <string>

struct ContentResolverResult
{
    int fileDescriptor = -1;
    std::string error;

    bool success() const
    {
        return fileDescriptor >= 0;
    }
};