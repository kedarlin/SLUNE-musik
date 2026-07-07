#pragma once
#include "IDataSource.h"

#include <fstream>

class FileDataSource : public IDataSource
{
public:
    FileDataSource() = default;
    ~FileDataSource() override;

    bool open(const std::string &uri) override;
    void close() override;
    size_t read(
        uint8_t *buffer,
        size_t size) override;
    bool seek(int64_t offset) override;
    int64_t position() const override;
    int64_t length() const override;
    bool isOpen() const override;

private:
    std::ifstream stream_;
    int64_t length_ = 0;
};