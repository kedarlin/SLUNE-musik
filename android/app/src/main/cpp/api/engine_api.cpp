#include "engine_api.h"

#include "../engine/AudioEngine.h"

#include <memory>

static std::unique_ptr<AudioEngine> g_engine;

bool engine_seek(int64_t positionUs)
{
    return gEngine.seek(positionUs) == ProcessResult::Continue;
}

bool engine_initialize()
{
    if (!g_engine)
    {
        g_engine = std::make_unique<AudioEngine>();
    }

    return g_engine->initialize();
}

bool engine_load_track(const char *path)
{
    if (!g_engine)
    {
        return false;
    }

    return g_engine->loadTrack(path);
}

void engine_play()
{
    if (g_engine)
    {
        g_engine->play();
    }
}

void engine_pause()
{
    if (g_engine)
    {
        g_engine->pause();
    }
}

void engine_release()
{
    if (g_engine)
    {
        g_engine->release();
        g_engine.reset();
    }
}