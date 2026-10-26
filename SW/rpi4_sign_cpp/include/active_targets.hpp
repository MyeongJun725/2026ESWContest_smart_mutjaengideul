#pragma once
#include "sign_runtime.hpp"
#include <string>
#include <vector>
namespace sign_engine {
struct ActiveTargetReference { int id; std::vector<float> feature; };
struct ActiveTargetModel { std::vector<ActiveTargetReference> references; };
struct ActiveTargetDiagnostics {
 bool evaluated=false,accepted=false;
 std::size_t paired_frames=0;
 int candidate=-1;
 double distance=0,runner_up=0,left_motion=0,right_motion=0;
 std::string reason;
};
ActiveTargetModel loadActiveTargetModel(const std::string& path);
SignRecognitionResult classifyWithActiveTargets(const RecordingFrames& frames,
 const RuntimeData& runtime,const ActiveTargetModel& model,
 ActiveTargetDiagnostics& diagnostics);
} // namespace sign_engine
