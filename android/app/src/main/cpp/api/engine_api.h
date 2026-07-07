#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

    bool engine_initialize();

    void engine_play();

    void engine_pause();

    void engine_release();

#ifdef __cplusplus
}
#endif