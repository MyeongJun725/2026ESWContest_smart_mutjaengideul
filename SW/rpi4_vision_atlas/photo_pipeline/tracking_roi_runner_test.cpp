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
    std::cout<<"PASS: shared production runner scope, one-call bound, side/wrist/duplicate rejection\n";
}
