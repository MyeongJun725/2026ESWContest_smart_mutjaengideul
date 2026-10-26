#include "tracking_roi_retry_policy.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>
#include <cstring>
using namespace vision_runtime;
int main(){
    // Actual recorded failed tracker candidates and their square-crop results.
    struct R{double old_score,new_score,raw,distance,span;int side;};
    const R samples[]={{.357221,.9317,.858,28.1,74,1},{.735595,.9311,.886,24.9,83,1},{.7923,.906,.077,26.4,104,-1}};
    for(const auto& r:samples){
        assert(eligibleTrackingRoiRetry(true,2,r.side,r.old_score,0));
        assert(trackingRoiRetryRejection(r.new_score,r.raw,r.side,r.distance,r.span,true,false)==nullptr);
    }
    assert(!eligibleTrackingRoiRetry(false,2,1,.5,0));
    assert(!eligibleTrackingRoiRetry(true,1,1,.5,0));
    assert(!eligibleTrackingRoiRetry(true,2,0,.5,0));
    assert(!eligibleTrackingRoiRetry(true,2,1,.5,1));
    assert(!eligibleTrackingRoiRetry(true,2,1,.1,0));
    assert(!eligibleTrackingRoiRetry(true,2,1,.9,0));
    assert(!eligibleTrackingRoiRetry(true,2,1,std::numeric_limits<double>::quiet_NaN(),0));
    assert(!std::strcmp(trackingRoiRetryRejection(.799,.9,1,10,100,true,false),"LOW_CONFIDENCE"));
    assert(!std::strcmp(trackingRoiRetryRejection(.99,.1,1,10,100,true,false),"SIDE_CHANGED"));
    assert(!std::strcmp(trackingRoiRetryRejection(.99,.9,1,101,100,true,false),"WRIST_MOVED"));
    assert(!std::strcmp(trackingRoiRetryRejection(.99,.9,1,10,100,false,false),"WRIST_MOVED"));
    assert(!std::strcmp(trackingRoiRetryRejection(.99,.9,1,10,100,true,true),"DUPLICATE_WRIST"));
    std::cout<<"PASS: recorded tracker recoveries; one-hand/detector/high-score inputs preserved; one retry limit; side/wrist/duplicate guards\n";
}
