#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

class IDataSource
{
public:
    virtual ~IDataSource() = default;
    virtual bool open(const std::string &uri) = 0;
    virtual void close() = 0;
    virtual size_t read(
        uint8_t *buffer,
        size_t size) = 0;
    virtual bool seek(int64_t offset) = 0;
    virtual int64_t position() const = 0;
    virtual int64_t length() const = 0;
    virtual bool isOpen() const = 0;
};