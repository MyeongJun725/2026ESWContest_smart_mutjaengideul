#include "hand_observation_policy.hpp"
#include "palm_retry_policy.hpp"
#include <cassert>
#include <iostream>

using namespace vision_runtime;
struct Observed { HandGeometry geometry; int id; };
HandGeometry geometry(double x, double y) {
    HandGeometry h;
    for (int i=0; i<21; ++i) h.points[i]={x+(i%5)*8, y-(i/5)*10};
    return h;
}
int main() {
    auto first=geometry(100,100), duplicate=geometry(101,101);
    assert(sameObservedHand(first, duplicate));
    auto second=geometry(104,102);
    for (int i=1;i<21;++i) second.points[i][0]+=22;
    assert(!sameObservedHand(first,second)); // close wrists, distinct fingers
    std::vector<Observed> kept{{first,1}};
    mergeFreshHands(kept, std::vector<Observed>{{duplicate,2},{second,3}},
        [](const Observed& h){return h.geometry;});
    assert(kept.size()==2 && kept[0].id==1 && kept[1].id==3);
    mergeFreshHands(kept, std::vector<Observed>{{geometry(300,100),4}},
        [](const Observed& h){return h.geometry;});
    assert(kept.size()==2);
    InferenceBudget budget;
    for (int i=0;i<5;++i) assert(budget.takeHand());
    assert(!budget.takeHand() && budget.hand_calls==5);
    assert(budget.takePalm() && !budget.takePalm());

    for (double fps : {3.0,10.0,30.0}) {
        LostSecondHandRecovery policy;
        policy.observe(2,1,100);
        unsigned scans=0;
        for(double ms=100;ms<1600;ms+=1000/fps) {
            scans+=policy.beginFrame(ms)?1:0;
            policy.observe(1,1,ms);
        }
        assert(scans>0 && scans<=4 && !policy.recovering(1600));
        policy.observe(2,0,1700);
        assert(policy.recovering(1700)); // total occlusion retains bounded search
        policy.observe(0,2,1800);
        assert(!policy.recovering(1800));
    }
    // Invert known preprocessing coordinates, including odd padding and rotation.
    for(int side : {75,76,121}) for(double radians : {0.0,.7,-1.1}) {
        const double c=std::cos(radians),s=std::sin(radians);
        const std::array<double,6> inverse{c,-s,11,s,c,-7};
        for (auto model : {std::array<double,2>{0,0},{112,112},{223,207}}) {
            auto p=restoreCropPoint(model[0],model[1],side,3,-9,inverse,17,21);
            const double x=model[0]*side/224+3, y=model[1]*side/224-9;
            assert(std::abs(p[0]-(c*x-s*y+28))<1e-9);
            assert(std::abs(p[1]-(s*x+c*y+14))<1e-9);
        }
    }
    std::cout << "PASS: fresh merge, duplicate/overlap distinction, budget, timed recovery, crop inverse\n";
}
