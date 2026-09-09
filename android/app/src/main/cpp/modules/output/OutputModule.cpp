#include "OutputModule.h"

#include "../../context/EngineContext.h"

bool OutputModule::initialize(EngineContext &context)
{
    return output_.initialize(context, pipeline_);
}

AudioPipeline &OutputModule::pipeline()
{
    return pipeline_;
}

void OutputModule::shutdown()
{
    output_.shutdown();
}