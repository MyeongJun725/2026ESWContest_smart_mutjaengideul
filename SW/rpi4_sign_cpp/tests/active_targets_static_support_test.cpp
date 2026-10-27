// Routing regression with constructed static-support input and in-memory test
// references. This is not a WORD1229 accuracy test or a training reference.
#include "active_targets.hpp"
#include "runtime_data.hpp"
#include "temporal_resample.hpp"
#include <cassert>
#include <fstream>
#include <iostream>

using namespace sign_engine;
HandSequence fixture(const char* name) {
    const std::string path=std::string("SW/rpi4_sign_cpp/tests/fixtures/sign_runtime_routes_frozen/")+name;
    std::ifstream input(path,std::ios::binary);
    std::vector<float> values(87*21*2);
    assert(input.read(reinterpret_cast<char*>(values.data()),values.size()*sizeof(float)));
    HandSequence hands(87);
    for(std::size_t f=0;f<87;++f) for(std::size_t p=0;p<21;++p)
        hands[f].points[p]={values[(f*21+p)*2],values[(f*21+p)*2+1]};
    return hands;
}
ActiveTargetModel test_model(const RecordingFrames& frames, int exact_id) {
    HandSequence left,right;
    for(const auto& f:frames) if(f.has_left&&f.has_right){left.push_back(f.left);right.push_back(f.right);}
    FeatureV3Options options;options.one_hand_ratio_threshold=0;options.no_motion_threshold=0;
    options.anchor_frame_count=5;options.canonical_hand=CanonicalHand::Right;
    const auto raw=buildHandFeaturesV3(&left,&right,options);
    const auto full=temporalResample(raw.features,raw.frame_count,172,80);
    ActiveTargetModel model;
    for(int id:{0,1,3,4,5,6,9,12,14,15}) {
        ActiveTargetReference ref;ref.id=id;
        for(int t=0;t<80;++t) for(int d=0;d<168;++d)
            ref.feature.push_back(full[t*172+d]+(id==exact_id?0.f:4.f));
        model.references.push_back(std::move(ref));
    }
    return model;
}
int main() {
    auto left=fixture("input_real01_left_87x21x2.bin");
    auto right=fixture("input_real01_right_87x21x2.bin");
    RecordingFrames frames;
    for(std::size_t i=0;i<right.size();++i){
        FrameHands f;f.has_left=f.has_right=true;f.left=left[0];f.right=right[i];frames.push_back(f);
    }
    const auto runtime=loadRuntimeData("SW/rpi4_sign_cpp/runtime_data");
    const auto baseline=classifyRecording(frames,runtime);
    assert(baseline.valid && baseline.usage_type==UsageType::OneHand);
    ActiveTargetDiagnostics diagnostic;
    const auto result=classifyWithActiveTargets(frames,runtime,test_model(frames,15),diagnostic);
    assert(result.valid && result.final_id==15 && diagnostic.accepted);
    assert(diagnostic.paired_frames==87 && diagnostic.left_motion==0 && diagnostic.right_motion>=.5);
    // A moving dominant hand with a passive other hand is not sufficient:
    // a non-WORD1229 nearest reference must preserve the original classifier.
    const auto other=classifyWithActiveTargets(frames,runtime,test_model(frames,5),diagnostic);
    assert(other.valid==baseline.valid && other.final_id==baseline.final_id && other.stage==baseline.stage);
    // Pure one-hand input cannot be converted into a two-hand target.
    auto single=frames;for(auto& f:single)f.has_left=false;
    const auto single_baseline=classifyRecording(single,runtime);
    const auto single_result=classifyWithActiveTargets(single,runtime,test_model(frames,15),diagnostic);
    assert(single_result.final_id==single_baseline.final_id && single_result.stage==single_baseline.stage);
    // A competing near reference fails the unchanged relative-distance margin.
    auto ambiguous=test_model(frames,15);
    ambiguous.references[0].feature=ambiguous.references.back().feature;
    const auto uncertain=classifyWithActiveTargets(frames,runtime,ambiguous,diagnostic);
    assert(uncertain.final_id==baseline.final_id && !diagnostic.accepted);
    std::cout<<"PASS: static support target route, one-hand controls, competing references\n";
}
