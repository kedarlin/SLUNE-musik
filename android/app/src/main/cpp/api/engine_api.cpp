#include "engine_api.h"

#include "../engine/AudioEngine.h"

#include <memory>

static std::unique_ptr<AudioEngine> g_engine;

bool engine_initialize()
{
    if (!g_engine)
    {
        g_engine = std::make_unique<AudioEngine>();
    }

    return g_engine->initialize();
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