#include "FileDataSource.h"

#include "../common/Logger.h"

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

FileDataSource::~FileDataSource()
{
    close();
}

bool FileDataSource::open(const std::string &uri)
{
    close();

    fd_ = ::open(uri.c_str(), O_RDONLY);

    if (fd_ < 0)
    {
        LOGE("Failed to open file: %s", uri.c_str());
        return false;
    }

    struct stat fileStat{};

    if (fstat(fd_, &fileStat) != 0)
    {
        LOGE("Failed to read file information.");
        close();
        return false;
    }

    length_ = static_cast<int64_t>(fileStat.st_size);
    path_ = uri;

    LOGI("Opened file: %s", uri.c_str());
    return true;
}

void FileDataSource::close()
{
    if (fd_ >= 0)
    {
        ::close(fd_);
        fd_ = -1;
    }
}

size_t FileDataSource::read(
    uint8_t *buffer,
    size_t size)
{
    if (fd_ < 0)
    {
        return 0;
    }

    ssize_t bytesRead = ::read(fd_, buffer, size);

    if (bytesRead < 0)
    {
        return 0;
    }

    return static_cast<size_t>(bytesRead);
}

bool FileDataSource::seek(int64_t offset)
{
    if (fd_ < 0)
    {
        return false;
    }

    return lseek(fd_, offset, SEEK_SET) != -1;
}

int64_t FileDataSource::position() const
{
    if (fd_ < 0)
    {
        return 0;
    }

    return static_cast<int64_t>(
        lseek(fd_, 0, SEEK_CUR));
}

int64_t FileDataSource::length() const
{
    return length_;
}

bool FileDataSource::isOpen() const
{
    return fd_ >= 0;
}

int FileDataSource::fileDescriptor() const
{
    return fd_;
}

int64_t FileDataSource::startOffset() const
{
    return 0;
}