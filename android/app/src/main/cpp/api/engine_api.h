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

    double engine_get_position_seconds();

    double engine_get_duration_seconds();

    bool engine_is_playing();

#ifdef __cplusplus
}
#endif