#pragma once
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <stdexcept>
#include <vector>

namespace vision_runtime {
// Recognition-only, bounded exposure compensation. The caller keeps the raw
// preview frame. This cannot restore image detail clipped by the camera.
class RecognitionLight {
public:
    double reference=0, measured=0, gain=1, gamma=1, clipped_fraction=0;
    bool calibration_finished=false;
    void setReference(double value) {
        if (!std::isfinite(value) || value<5 || value>250)
            throw std::invalid_argument("Invalid recognition light reference");
        reference=value;
    }
    void calibrate(double now_ms) {
        calibration_start_=now_ms;
        samples_.clear();
        reference=0; gain=1; gamma=1; previous_ms_=-1;
    }
    cv::Mat apply(const cv::Mat& raw, double now_ms) {
        if (raw.empty() || raw.type()!=CV_8UC3)
            throw std::invalid_argument("Recognition light expects BGR8");
        calibration_finished=false;
        // A fixed working zone avoids most of the camera border and foreground
        // at the far left. Downsampling and a trimmed mean limit background glare.
        cv::Rect zone(int(raw.cols*.20),int(raw.rows*.10),
                      std::max(1,int(raw.cols*.70)),std::max(1,int(raw.rows*.80)));
        zone &= cv::Rect(0,0,raw.cols,raw.rows);
        cv::Mat small,gray;
        cv::resize(raw(zone),small,{64,64},0,0,cv::INTER_AREA);
        cv::cvtColor(small,gray,cv::COLOR_BGR2GRAY);
        std::vector<unsigned char> values(gray.datastart,gray.dataend);
        clipped_fraction=double(std::count_if(values.begin(),values.end(),
            [](unsigned char v){return v>=250;}))/values.size();
        std::sort(values.begin(),values.end());
        const std::size_t trim=values.size()/10;
        double sum=0;
        for(std::size_t i=trim;i<values.size()-trim;++i)sum+=values[i];
        measured=sum/(values.size()-2*trim);
        if (calibration_start_>=0) {
            // Let camera auto-exposure settle after stream startup.
            if (now_ms-calibration_start_>=2000 && measured>=5 && measured<=250)
                samples_.push_back(measured);
            if (samples_.size()>=15) {
                std::sort(samples_.begin(),samples_.end());
                reference=samples_[samples_.size()/2];
                calibration_start_=-1;
                calibration_finished=true;
            }
            previous_ms_=now_ms;
            return raw;
        }
        if (reference<=0) return raw;
        // Preserve bright hand detail instead of multiplying every pixel by
        // the same exposure gain. A white/clipped pixel remains unrecoverable.
        const double target=measured>reference*1.08
            ? std::clamp(std::log(reference/255.)/
                         std::log(std::clamp(measured,1.,254.)/255.),1.,4.) : 1.;
        const double dt=previous_ms_<0 ? 1000. : std::max(0.,now_ms-previous_ms_);
        const double alpha=1.-std::exp(-std::min(dt,1000.)/250.);
        gamma+=alpha*(target-gamma);
        gain=measured>0 ? std::pow(measured/255.,gamma-1.) : 1.;
        previous_ms_=now_ms;
        if (gamma<1.001) return raw;
        std::array<float,256> scales{};scales[0]=1;
        for(int value=1;value<256;++value)
            scales[value]=float(std::pow(value/255.,gamma-1.));
        cv::Mat full_gray,corrected(raw.size(),raw.type());
        cv::cvtColor(raw,full_gray,cv::COLOR_BGR2GRAY);
        for(int y=0;y<raw.rows;++y) {
            const auto* input=raw.ptr<cv::Vec3b>(y);
            const auto* luminance=full_gray.ptr<unsigned char>(y);
            auto* output=corrected.ptr<cv::Vec3b>(y);
            for(int x=0;x<raw.cols;++x) for(int channel=0;channel<3;++channel)
                output[x][channel]=cv::saturate_cast<unsigned char>(input[x][channel]*scales[luminance[x]]);
        }
        return corrected;
    }
private:
    double calibration_start_=-1,previous_ms_=-1;
    std::vector<double> samples_;
};
} // namespace vision_runtime
