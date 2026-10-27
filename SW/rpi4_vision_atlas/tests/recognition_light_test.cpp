#include "recognition_light.hpp"
#include <cassert>
#include <iostream>
int main() {
    using vision_runtime::RecognitionLight;
    cv::Mat raw(480,640,CV_8UC3,cv::Scalar(200,200,200));
    auto before=raw.clone();
    RecognitionLight light;light.setReference(100);
    auto adjusted=light.apply(raw,1000);
    assert(cv::norm(raw,before,cv::NORM_INF)==0); // preview remains untouched
    assert(cv::mean(adjusted)[0]>=99 && cv::mean(adjusted)[0]<=103);
    assert(light.gain>=.49 && light.gain<.52);
    RecognitionLight disabled;
    assert(disabled.apply(raw,1000).data==raw.data);
    RecognitionLight darker;darker.setReference(100);
    cv::Mat dark(480,640,CV_8UC3,cv::Scalar(50,50,50));
    assert(darker.apply(dark,1000).data==dark.data); // do not amplify dark noise
    RecognitionLight baseline;baseline.calibrate(0);
    cv::Mat working(480,640,CV_8UC3,cv::Scalar(80,80,80));
    for(int i=0;i<25;++i)baseline.apply(working,i*200.);
    assert(baseline.calibration_finished && std::abs(baseline.reference-80)<.001);
    RecognitionLight clipped;clipped.setReference(80);
    cv::Mat white(480,640,CV_8UC3,cv::Scalar(255,255,255));
    clipped.apply(white,1000);
    assert(clipped.clipped_fraction==1 && clipped.gamma<=4);
    assert(std::abs(cv::mean(clipped.apply(white,1200))[0]-255)<1e-9); // clipped detail cannot be restored
    // A nonlinear curve retains highlights that a uniform multiplier erased.
    RecognitionLight highlights;highlights.setReference(100);
    cv::Mat scene(480,640,CV_8UC3,cv::Scalar(200,200,200));
    scene.at<cv::Vec3b>(240,320)={240,240,240};
    const auto preserved=highlights.apply(scene,1000);
    assert(preserved.at<cv::Vec3b>(240,320)[0]>180);
    // Colour channels use the same gain; no inferred hand coordinates change.
    RecognitionLight colour;colour.setReference(80);
    cv::Mat rgb(480,640,CV_8UC3,cv::Scalar(120,180,220));
    auto c=colour.apply(rgb,1000).at<cv::Vec3b>(240,320);
    assert(std::abs(double(c[0])/c[2]-120./220)<.02);
    std::cout<<"PASS: recognition-only light reference, raw preview, bounds, calibration, clipping\n";
}
