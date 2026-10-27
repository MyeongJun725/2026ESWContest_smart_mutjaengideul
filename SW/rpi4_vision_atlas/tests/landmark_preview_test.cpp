#include "landmark_preview.hpp"
#include <cassert>
#include <iostream>
int main() {
    using namespace vision_runtime;
    const cv::Mat raw(480,640,CV_8UC3,cv::Scalar(80,90,100));
    const auto original=raw.clone();
    PreviewHand hand;
    for(int i=0;i<21;++i)hand.geometry.points[i]={100.+(i%5)*20,100.+(i/5)*20};
    const auto drawn=drawHandLandmarks(raw,{hand});
    assert(cv::norm(raw,original,cv::NORM_INF)==0);
    assert(cv::norm(drawn,raw,cv::NORM_INF)>0);
    LandmarkPreview preview;
    const auto t=LandmarkPreview::Clock::time_point{}+std::chrono::seconds(10);
    assert(!preview.snapshot(t));
    preview.publish(raw,{hand},t,t);
    auto retained=preview.snapshot(t+std::chrono::milliseconds(200));
    assert(retained && cv::norm(*retained,raw,cv::NORM_INF)>0);
    // A fresh empty detection clears old joints, while old shared snapshots
    // remain immutable for a concurrent sender.
    preview.publish(raw,{},t+std::chrono::milliseconds(250),t+std::chrono::milliseconds(250));
    auto empty=preview.snapshot(t+std::chrono::milliseconds(300));
    assert(empty && cv::norm(*empty,raw,cv::NORM_INF)==0);
    assert(cv::norm(*retained,raw,cv::NORM_INF)>0);
    assert(!preview.snapshot(t+std::chrono::milliseconds(751)));
    assert(!preview.snapshot(t));
    // Slow inference must still display its matching completed image, bounded
    // from completion. It must not disappear before the sender can use it.
    preview.publish(raw,{hand},t,t+std::chrono::milliseconds(800));
    assert(preview.snapshot(t+std::chrono::milliseconds(900)));
    assert(!preview.snapshot(t+std::chrono::milliseconds(1301)));
    std::cout<<"PASS: fresh same-frame landmarks, raw input unchanged, empty/stale clearing\n";
}
