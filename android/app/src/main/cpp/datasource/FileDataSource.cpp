#include "FileDataSource.h"

#include "../common/Logger.h"

FileDataSource::~FileDataSource()
{
    close();
}

bool FileDataSource::open(const std::string &uri)
{
    close();

    stream_.open(uri, std::ios::binary);

    if (!stream_.is_open())
    {
        LOGE("Failed to open file: %s", uri.c_str());
        return false;
    }

    stream_.seekg(0, std::ios::end);
    length_ = static_cast<int64_t>(stream_.tellg());
    stream_.seekg(0, std::ios::beg);

    LOGI("Opened file: %s", uri.c_str());

    return true;
}

void FileDataSource::close()
{
    if (stream_.is_open())
    {
        stream_.close();
        length_ = 0;
    }
}

size_t FileDataSource::read(
    uint8_t *buffer,
    size_t size)
{
    if (!stream_.is_open())
    {
        return 0;
    }

    stream_.read(reinterpret_cast<char *>(buffer), size);

    return static_cast<size_t>(stream_.gcount());
}

bool FileDataSource::seek(int64_t offset)
{
    if (!stream_.is_open())
    {
        return false;
    }

    stream_.seekg(offset, std::ios::beg);

    return stream_.good();
}

int64_t FileDataSource::position() const
{
    if (!stream_.is_open())
    {
        return 0;
    }

    return static_cast<int64_t>(
        const_cast<std::ifstream &>(stream_).tellg());
}

int64_t FileDataSource::length() const
{
    return length_;
}

bool FileDataSource::isOpen() const
{
    return stream_.is_open();
}