#pragma once

#include "IDataSource.h"

#include <string>

class ContentDataSource : public IDataSource
{
public:
    ContentDataSource() = default;
    ~ContentDataSource() override;

    bool open(const std::string &uri) override;

    void close() override;

    size_t read(uint8_t *buffer,
                size_t size) override;

    bool seek(int64_t offset) override;

    int64_t position() const override;

    int64_t length() const override;

    bool isOpen() const override;

    int fileDescriptor() const override;

    int64_t startOffset() const override;

private:
    int fd_ = -1;

    int64_t length_ = 0;

    std::string uri_;
};