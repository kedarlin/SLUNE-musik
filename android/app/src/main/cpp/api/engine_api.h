#pragma once

#include <cstdint>

#ifdef __cplusplus
extern "C"
{
#endif

    bool engine_initialize();

    bool engine_load_track(const char *path);

    void engine_play();

    void engine_pause();

    bool engine_seek(int64_t positionUs);

    void engine_release();

#ifdef __cplusplus
}
#endif