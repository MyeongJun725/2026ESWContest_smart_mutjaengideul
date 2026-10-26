#include "live_sign_session.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>

int main() {
    // Slow inference is not evidence that hands disappeared between captures.
    for(bool recovering : {false,true}) {
        LiveSignSession slow;
        double t=0;
        for(int i=0;i<30;++i) {
            t += (i%3==0 ? 800 : i%3==1 ? 1500 : 1100);
            assert(!slow.push({{}},t,recovering));
        }
        auto continuous=slow.flush();
        assert(continuous && continuous->size()==30);

        LiveSignSession missed;
        t=0;
        for(int i=0;i<30;++i) {
            t += (i%3==0 ? 800 : i%3==1 ? 1500 : 1100);
            assert(!missed.push(i==12 ? sign_engine::VisionFrameDetections{} :
                sign_engine::VisionFrameDetections{{}},t,recovering));
        }
        auto isolated_miss=missed.flush();
        assert(isolated_miss && isolated_miss->size()==30);

        // Sustained observed absence still closes the segment at slow cadence.
        LiveSignSession bounded;
        t=0;
        for(int i=0;i<20;++i) { bounded.push({{}},t,recovering);t+=1500; }
        assert(!bounded.push({},t,recovering));
        assert(!bounded.push({},t+1500,recovering));
        auto ended=bounded.push({},t+3000,recovering);
        assert(ended && ended->size()==20 && !bounded.isRecording());
    }
    for(double fps : {5.0,15.0,30.0}) {
        LiveSignSession session;
        double now=0;
        for(int i=0;i<20;++i){assert(!session.push({{}},now,false));now+=1000/fps;}
        const double gap=now;
        assert(!session.push({},now,false));
        std::optional<sign_engine::VisionRecordingDetections> result;
        while(!result && now-gap<1000) {now+=1000/fps;result=session.push({},now,false);}
        assert(result && result->size()==20);
        assert(now-gap>=350 && now-gap<350+1000/fps+1);
    }
    LiveSignSession recovery;
    double now=0;
    for(int i=0;i<20;++i){recovery.push({{},{}},now,true);now+=40;}
    for(int i=0;i<6;++i){assert(!recovery.push({},now,true));now+=40;}
    assert(!recovery.push({{}},now,true));
    for(int i=0;i<7;++i){now+=40;recovery.push({{}},now,false);}
    now+=40;recovery.push({},now,false);
    auto end=recovery.push({},now+351,false);
    assert(end && end->size()==34); // 28 observed + 6 actual empty observations
    std::size_t observed=0;for(const auto& f:*end)observed+=!f.empty();
    assert(observed==28); // missing coordinates were never filled

    LiveSignSession split;
    for(int i=0;i<20;++i)split.push({{}},i*40,false);
    split.push({},800,true);
    auto old=split.push({{}},1500,true);
    assert(old && old->size()==20 && split.isRecording());
    auto too_short=split.flush();assert(!too_short); // new sign has one actual frame
    bool rejected=false;
    try{split.push({},1400,false);}catch(const std::invalid_argument&){rejected=true;}
    assert(rejected);
    std::cout<<"PASS: time-based boundaries, bounded occlusion, no stale hands, distinct actions\n";
}
