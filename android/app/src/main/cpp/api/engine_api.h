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

    bool engine_set_speed(float speed);

    bool engine_set_pitch(float pitch);

#ifdef __cplusplus
}
#endif