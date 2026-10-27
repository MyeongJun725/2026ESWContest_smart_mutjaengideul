#include <opencv2/core.hpp>
#include "tracking_roi_retry_policy.hpp"
#include "hand_observation_policy.hpp"
#include <algorithm>
#include <array>
#include <cassert>
#include <iostream>
#include <vector>

struct Palm {int tracked_side=0,id=-1;double score=.99;std::array<double,4> box;std::array<cv::Point2d,7> points{};};
struct Hand {Palm palm{};double confidence=0,handedness=0;std::array<cv::Point2f,21> xy{}; std::array<int,4> crop_box{};int palm_points_outside_crop=0;double crop_angle=0;bool invalid_crop=false;};
struct Reply {bool square;double confidence,raw;float x,y;};
struct Model {std::vector<Reply> replies;std::size_t next=0;};
bool hand(const cv::Mat&,const Palm& palm,Model& model,Hand& out,bool square=false){
    assert(model.next<model.replies.size());const auto r=model.replies[model.next++];assert(r.square==square);
    if(r.confidence<0)throw vision_runtime::InvalidHandCrop("synthetic invalid ROI");
    out.confidence=r.confidence;out.handedness=r.raw;
    if(r.confidence<.8)return false;
    out.palm=palm;
    for(int i=0;i<21;++i)out.xy[i]={r.x+(i%5)*8,r.y-(i/5)*10};
    return true;
}
#include "tracking_roi_runner.inc"
Palm makePalm(int side,double x0,double y0,double x1,double y1,double wx,double wy){Palm p;p.tracked_side=side;p.box={x0,y0,x1,y1};p.points[0]={wx,wy};return p;}
int main(){
    struct Fixture{const char* name;std::vector<Palm> palms;std::vector<Reply> replies;};
    std::vector<Fixture> fixtures;
    #include "roi_runner_cases.inc"
    const cv::Mat image(480,640,CV_8UC3);
    for(const auto& f:fixtures){
        Model model{f.replies};bool failure=true;vision_runtime::TrackingRoiRetryDiagnostics diag;
        const auto result=run_hands(image,f.palms,model,failure,true,diag);
        assert(!failure&&result.size()==2&&diag.attempted==1&&diag.accepted==1&&model.next==3);
        for(int i=0;i<2;++i)if(f.replies[i].confidence>=.8){
            assert(result[i].confidence==f.replies[i].confidence&&result[i].handedness==f.replies[i].raw);
            assert(result[i].xy[0]==cv::Point2f(f.replies[i].x,f.replies[i].y));
        }
        std::cout<<"PASS: recorded "<<f.name<<" recovers failed tracker; original accepted hand unchanged\n";
    }
    auto palms=fixtures[0].palms;
    // Successful original crops, one hand, and detector mode never add model calls.
    for(int mode=0;mode<3;++mode){
        auto inputs=palms;Model m;
        if(mode==1){inputs.resize(1);m.replies={{false,.4,.9,0,0}};}
        else if(mode==2)m.replies={{false,.4,.9,0,0},{false,.95,.1,500,100}};
        else m.replies={{false,.95,.9,350,250},{false,.96,.1,500,100}};
        const auto count=m.replies.size();bool failure;vision_runtime::TrackingRoiRetryDiagnostics diag;
        run_hands(image,inputs,m,failure,mode!=2,diag);
        assert(m.next==count&&diag.attempted==0&&diag.accepted==0);
    }
    // Reject a plausible-looking retry that swaps physical side, jumps away, or duplicates the other wrist.
    palms={makePalm(1,300,200,400,300,350,250),makePalm(-1,350,200,450,300,400,250)};
    for(int mode=0;mode<4;++mode){
        Reply retry{true,.99,.9,350,250};
        if(mode==0)retry.raw=.1;
        if(mode==1)retry.x=600;
        if(mode==2)retry.x=400;
        if(mode==3)retry.confidence=.7;
        Model m{{{false,.5,.9,0,0},{false,.95,.1,400,250},retry}};
        bool failure;vision_runtime::TrackingRoiRetryDiagnostics diag;
        auto result=run_hands(image,palms,m,failure,true,diag);
        assert(failure&&result.size()==1&&diag.attempted==1&&diag.accepted==0&&m.next==3);
    }
    // Two rejected originals still receive no more than one extra call, then existing fallback may run.
    Model m{{{false,.5,.9,0,0},{false,.5,.1,0,0},{true,.5,.9,0,0}}};
    bool failure;vision_runtime::TrackingRoiRetryDiagnostics diag;
    assert(run_hands(image,palms,m,failure,true,diag).empty());
    assert(failure&&m.next==3&&diag.attempted==1);
    Model broken{{{false,.95,.9,350,250},{false,-1,.1,0,0}}};
    vision_runtime::TrackingRoiRetryDiagnostics broken_diag;
    auto surviving=run_hands(image,palms,broken,failure,true,broken_diag);
    assert(failure && surviving.size()==1 && broken.next==2);
    assert(broken_diag.candidates.size()==2 && broken_diag.candidates[1].invalid_crop);
    // A scheduled scan used to bypass tracking completely. A detector miss
    // must not erase the hand inferred successfully in this same frame.
    for (bool empty_scan : {false, true}) {
        auto tracked=std::vector<Palm>{palms[0]};
        Model scheduled{{{false,.95,.9,350,250}}};
        if (!empty_scan) scheduled.replies.push_back({false,.2,.1,0,0});
        vision_runtime::TrackingRoiRetryDiagnostics d;
        vision_runtime::InferenceBudget budget;
        unsigned scans=0;
        auto observation=observe_frame_hands(image,tracked,scheduled,true,true,
            [&](const std::vector<Hand>& kept) {
                ++scans; assert(kept.size()==1 && kept[0].xy[0]==cv::Point2f(350,250));
                assert(budget.takePalm());
                return empty_scan ? std::vector<Palm>{} : std::vector<Palm>{palms[1]};
            },d,budget);
        assert(observation.hands.size()==1 && observation.attempted_tracking);
        assert(observation.used_palm_detector && scans==1);
        assert(observation.hands[0].xy[0]==cv::Point2f(350,250));
        assert(scheduled.next==(empty_scan?1:2));
    }
    // Recovery keeps the live tracked hand, discards the detector's duplicate,
    // and admits a distinct newly observed hand, without exceeding five calls.
    Model recovery{{{false,.95,.9,350,250},{false,.96,.9,351,251},{false,.98,.1,500,100}}};
    vision_runtime::TrackingRoiRetryDiagnostics recovery_diag;
    vision_runtime::InferenceBudget recovery_budget;
    auto recovered=observe_frame_hands(image,{palms[0]},recovery,true,true,
        [&](const std::vector<Hand>&){assert(recovery_budget.takePalm());return palms;},
        recovery_diag,recovery_budget);
    assert(recovered.hands.size()==2 && recovery.next==3);
    assert(recovered.hands[0].confidence==.95 && recovered.hands[1].xy[0]==cv::Point2f(500,100));
    // Two valid current tracks do not need another palm or hand inference.
    Model complete{{{false,.95,.9,350,250},{false,.96,.1,500,100}}};
    vision_runtime::TrackingRoiRetryDiagnostics complete_diag;
    vision_runtime::InferenceBudget complete_budget;
    auto current=observe_frame_hands(image,palms,complete,true,true,
        [&](const std::vector<Hand>&)->std::vector<Palm>{assert(false);return {};},
        complete_diag,complete_budget);
    assert(current.hands.size()==2 && !current.used_palm_detector && complete.next==2);
    // A failed ROI is not returned as a hand from the previous frame.
    Model lost{{{false,.1,.9,0,0}}};
    vision_runtime::TrackingRoiRetryDiagnostics lost_diag;
    vision_runtime::InferenceBudget lost_budget;
    auto missing=observe_frame_hands(image,{palms[0]},lost,true,true,
        [&](const std::vector<Hand>& kept){assert(kept.empty());assert(lost_budget.takePalm());return std::vector<Palm>{};},
        lost_diag,lost_budget);
    assert(missing.hands.empty() && lost.next==1);
    // Worst case: two original tracks + one retry + two fresh candidates.
    Model bounded{{{false,.95,.9,350,250},{false,.4,.1,0,0},{true,.4,.1,0,0},
                   {false,.2,.1,0,0},{false,.97,.1,500,100}}};
    vision_runtime::TrackingRoiRetryDiagnostics bounded_diag;
    vision_runtime::InferenceBudget bounded_budget;
    auto bounded_result=observe_frame_hands(image,palms,bounded,true,true,
        [&](const std::vector<Hand>& kept){assert(kept.size()==1);assert(bounded_budget.takePalm());return palms;},
        bounded_diag,bounded_budget);
    assert(bounded_result.hands.size()==2 && bounded.next==5 && bounded_budget.hand_calls==5);
    assert(bounded_budget.palm_calls==1 && bounded_diag.attempted==1);
    // Explicit tracking backoff must not run even an available old ROI.
    Model bypass{{{false,.96,.1,500,100}}};
    vision_runtime::TrackingRoiRetryDiagnostics bypass_diag;
    vision_runtime::InferenceBudget bypass_budget;
    auto bypass_result=observe_frame_hands(image,palms,bypass,true,false,
        [&](const std::vector<Hand>& kept){assert(kept.empty());assert(bypass_budget.takePalm());return std::vector<Palm>{palms[1]};},
        bypass_diag,bypass_budget);
    assert(bypass_result.hands.size()==1 && !bypass_result.attempted_tracking && bypass.next==1);
    // A lost second ROI remains an inference input only, never a result.
    auto regions=missing_track_regions(palms,current.hands);
    assert(regions.empty()); // both current hands were freshly observed
    regions=missing_track_regions(palms,{current.hands[0]});
    assert(regions.size()==1 && regions[0].tracked_side==palms[1].tracked_side);
    auto retry_inputs=recovery_track_inputs({palms[0]},regions);
    assert(retry_inputs.size()==2);
    assert(recovery_track_inputs({palms[0]},{palms[0]}).size()==1);
    Model second_roi{{{false,.95,.9,350,250},{false,.96,.1,500,100}}};
    vision_runtime::TrackingRoiRetryDiagnostics second_roi_diag;
    vision_runtime::InferenceBudget second_roi_budget;
    auto second_observation=observe_frame_hands(image,retry_inputs,second_roi,true,true,
        [&](const std::vector<Hand>&)->std::vector<Palm>{assert(false);return {};},
        second_roi_diag,second_roi_budget);
    assert(second_observation.hands.size()==2 && second_roi.next==2);
    // A cached region rejected by fresh inference does not create a hand.
    Model hidden_roi{{{false,.95,.9,350,250},{false,.1,.1,0,0}}};
    vision_runtime::TrackingRoiRetryDiagnostics hidden_diag;
    vision_runtime::InferenceBudget hidden_budget;
    auto hidden_observation=observe_frame_hands(image,retry_inputs,hidden_roi,true,true,
        [&](const std::vector<Hand>&){assert(hidden_budget.takePalm());return std::vector<Palm>{};},
        hidden_diag,hidden_budget);
    assert(hidden_observation.hands.size()==1 && hidden_roi.next==2);
    auto same_side=current.hands;
    same_side[1].handedness=same_side[0].handedness;
    same_side[1].confidence=.99;
    const auto side_tracks=strongest_hand_per_side(same_side);
    assert(side_tracks.size()==1 && side_tracks[0].confidence==.99);
    assert(same_side.size()==2); // raw observations remain available for diagnosis
    assert(missing_track_regions(palms,same_side).size()==1);
    std::cout<<"PASS: shared production runner scope, one-call bound, side/wrist/duplicate rejection\n";
}
