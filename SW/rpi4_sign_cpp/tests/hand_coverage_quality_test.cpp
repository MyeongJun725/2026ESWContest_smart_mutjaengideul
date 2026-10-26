#include "hand_coverage_quality.hpp"
#include "sign_runtime.hpp"
#include "active_targets.hpp"
#include <cassert>
#include <iostream>

using namespace sign_engine;
FrameHands pair(bool contact) {
    FrameHands f;
    f.has_left=f.has_right=true;
    for(int i=0;i<21;++i) {
        f.left.points[i]={float(100+i%5*8),float(200-i/5*10)};
        f.right.points[i]={float((contact?110:400)+i%5*8),float(200-i/5*10)};
    }
    return f;
}
RecordingFrames clip(int paired, int tail, bool contact) {
    RecordingFrames frames(paired,pair(contact));
    auto single=pair(false);single.has_left=false;
    for(int i=0;i<tail;++i)frames.push_back(single);
    return frames;
}
int main() {
    // Synthetic shapes/counts; these are NOT the user's missing coordinate files.
    for(auto counts : {std::pair<int,int>{9,23},{4,42}}) {
        auto frames=clip(counts.first,counts.second,true);
        assert(assessHandCoverage(frames).incomplete_contact_sequence);
        const auto result=classifyRecording(frames,RuntimeData{});
        assert(!result.valid && result.final_id==-1 && !result.onehand_ran);
        assert(result.stage=="INCOMPLETE_TWO_HAND_TRACK");
        ActiveTargetDiagnostics diagnostics;
        const auto target=classifyWithActiveTargets(frames,RuntimeData{},ActiveTargetModel{},diagnostics);
        assert(!target.valid && diagnostics.reason=="INCOMPLETE_TWO_HAND_TRACK");
    }
    assert(!assessHandCoverage(clip(4,42,false)).incomplete_contact_sequence);
    assert(!assessHandCoverage(clip(2,40,true)).incomplete_contact_sequence);
    assert(!assessHandCoverage(clip(30,8,true)).incomplete_contact_sequence);
    assert(!assessHandCoverage(clip(0,40,false)).incomplete_contact_sequence);
    auto separate=clip(5,0,true);
    separate.insert(separate.end(),5,FrameHands{});
    auto single=clip(0,40,false);separate.insert(separate.end(),single.begin(),single.end());
    assert(!assessHandCoverage(separate).incomplete_contact_sequence);
    std::cout<<"PASS: incomplete contact loss withheld before both classification routes; normal controls retained\n";
}
