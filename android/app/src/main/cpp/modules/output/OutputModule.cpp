#include "OutputModule.h"

#include "../../context/EngineContext.h"

#include "../../common/Logger.h"

bool OutputModule::initialize(EngineContext &context)
{
    LOGI("OutoutModule initialized.");
    return output_.initialize(context, pipeline_);
}

AudioPipeline &OutputModule::pipeline()
{
    return pipeline_;
}

void OutputModule::shutdown()
{
    output_.shutdown();
    LOGI("OutputModule shutdown.");
}