#include "ContentDataSource.h"

#include "../common/Logger.h"
#include "../platform/android/AndroidContentResolver.h"

#include <sys/stat.h>
#include <unistd.h>

ContentDataSource::~ContentDataSource()
{
    close();
}

bool ContentDataSource::open(const std::string &uri)
{
    close();

    auto result = AndroidContentResolver::openFileDescriptor(uri);

    if (!result.success())
    {
        LOGE("%s", result.error.c_str());
        return false;
    }

    fd_ = result.fileDescriptor;
    uri_ = uri;

    struct stat fileStat{};

    if (fstat(fd_, &fileStat) == 0)
    {
        length_ = static_cast<int64_t>(fileStat.st_size);
    }

    LOGI("Opened content uri: %s", uri.c_str());

    return true;
}

void ContentDataSource::close()
{
    if (fd_ >= 0)
    {
        ::close(fd_);
        fd_ = -1;
    }

    length_ = 0;
    uri_.clear();
}

size_t ContentDataSource::read(uint8_t *buffer, size_t size)
{
    if (fd_ < 0)
    {
        return 0;
    }

    ssize_t bytesRead = ::read(fd_, buffer, size);

    return bytesRead > 0 ? static_cast<size_t>(bytesRead) : 0;
}

bool ContentDataSource::seek(int64_t offset)
{
    if (fd_ < 0)
    {
        return false;
    }

    return lseek(fd_, offset, SEEK_SET) != -1;
}

int64_t ContentDataSource::position() const
{
    if (fd_ < 0)
    {
        return 0;
    }

    return static_cast<int64_t>(
        lseek(fd_, 0, SEEK_CUR));
}

int64_t ContentDataSource::length() const
{
    return length_;
}

bool ContentDataSource::isOpen() const
{
    return fd_ >= 0;
}

int ContentDataSource::fileDescriptor() const
{
    return fd_;
}

int64_t ContentDataSource::startOffset() const
{
    return 0;
}