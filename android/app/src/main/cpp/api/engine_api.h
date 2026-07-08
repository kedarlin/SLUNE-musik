#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

    bool engine_initialize();

    bool engine_load_track(const char *path);

    void engine_play();

    void engine_pause();

    void engine_release();

#ifdef __cplusplus
}
#endif