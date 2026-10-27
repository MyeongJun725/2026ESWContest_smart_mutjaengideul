#pragma once
#include "hand_observation_policy.hpp"
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <chrono>
#include <memory>
#include <mutex>

namespace vision_runtime {
struct PreviewHand {
    HandGeometry geometry;
    bool left=false;
};

inline cv::Mat drawHandLandmarks(const cv::Mat& raw,const std::vector<PreviewHand>& hands) {
    auto canvas=raw.clone();
    constexpr std::array<std::array<int,2>,21> edges{{
        {0,1},{1,2},{2,3},{3,4},{0,5},{5,6},{6,7},{7,8},{5,9},{9,10},{10,11},
        {11,12},{9,13},{13,14},{14,15},{15,16},{13,17},{17,18},{18,19},{19,20},{0,17}}};
    for(const auto& hand:hands) {
        const cv::Scalar colour=hand.left ? cv::Scalar(70,220,100) : cv::Scalar(225,120,245);
        auto inside=[&](int i) {
            const auto& p=hand.geometry.points[i];
            return std::isfinite(p[0])&&std::isfinite(p[1])&&p[0]>=0&&p[1]>=0&&
                   p[0]<canvas.cols&&p[1]<canvas.rows;
        };
        auto point=[&](int i) {const auto& p=hand.geometry.points[i];return cv::Point(cvRound(p[0]),cvRound(p[1]));};
        for(const auto& edge:edges) if(inside(edge[0])&&inside(edge[1])) {
            cv::line(canvas,point(edge[0]),point(edge[1]),{20,20,20},5,cv::LINE_AA);
            cv::line(canvas,point(edge[0]),point(edge[1]),colour,2,cv::LINE_AA);
        }
        for(int i=0;i<21;++i) if(inside(i)) {
            cv::circle(canvas,point(i),4,{20,20,20},-1,cv::LINE_AA);
            cv::circle(canvas,point(i),3,colour,-1,cv::LINE_AA);
            cv::circle(canvas,point(i),1,{255,255,255},-1,cv::LINE_AA);
        }
    }
    return canvas;
}

// The capture thread keeps sending frames without waiting on inference. An
// overlay is paired with its own processed source frame, never a newer frame.
class LandmarkPreview {
public:
    using Clock=std::chrono::steady_clock;
    void publish(const cv::Mat& raw,const std::vector<PreviewHand>& hands,
                 Clock::time_point captured,Clock::time_point completed=Clock::now()) {
        auto rendered=std::make_shared<const cv::Mat>(drawHandLandmarks(raw,hands));
        std::lock_guard<std::mutex> lock(mutex_);
        frame_=std::move(rendered);captured_=captured;completed_=completed;
    }
    std::shared_ptr<const cv::Mat> snapshot(Clock::time_point now) {
        std::lock_guard<std::mutex> lock(mutex_);
        // An inference may itself take over 500ms. Expiring it from capture
        // time would hide every completed skeleton on a slow frame. The image
        // and joints still represent the same captured frame; expire a stalled
        // result from completion, rather than attaching joints to a newer image.
        if (!frame_ || now<completed_ || now-completed_>std::chrono::milliseconds(500)) return {};
        return frame_;
    }
private:
    std::mutex mutex_;
    std::shared_ptr<const cv::Mat> frame_;
    Clock::time_point captured_{},completed_{};
};
} // namespace vision_runtime
