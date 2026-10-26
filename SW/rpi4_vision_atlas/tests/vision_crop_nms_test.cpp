#define VISION_RAW_ONLY
#define VISION_PHOTO_NO_MAIN
// Scripted model outputs do not load an ONNX session in this host geometry test.
#define ORT_API_MANUAL_INIT
#include "vision_photo.cpp"
#include <cassert>

struct FakeHandModel {
    float confidence=.95f;
    std::vector<std::vector<float>> run(std::vector<float>& input,
        const std::vector<const char*>&, const std::vector<std::vector<int64_t>>&) {
        assert(input.size()==224*224*3);
        std::vector<std::vector<float>> out(4);
        out[0].resize(63);out[1]={confidence};out[2]={.8f};out[3].resize(63);
        for(int i=0;i<21;++i){out[0][i*3]=112+(i%5)*3;out[0][i*3+1]=112-(i/5)*3;}
        return out;
    }
};
struct FakePalmModel {
    std::vector<std::vector<float>> run(std::vector<float>& input,
        const std::vector<const char*>&, const std::vector<std::vector<int64_t>>&) {
        assert(input.size()==192*192*3);
        std::vector<std::vector<float>> out{std::vector<float>(2016*18),std::vector<float>(2016,-100)};
        for(int id=0;id<3;++id) {
            out[1][id]=float(8-id);
            const double ax=(id/2+.5)/24,ay=.5/24;
            const double x=id==2?450:300, y=240;
            out[0][id*18]=float((x/640-ax)*192);
            out[0][id*18+1]=float(((y+80)/640-ay)*192);
            out[0][id*18+2]=out[0][id*18+3]=24;
            for(int k=0;k<7;++k){
                out[0][id*18+4+k*2]=float(((x+(id==1?15:0))/640-ax)*192);
                out[0][id*18+5+k*2]=float(((y+80)/640-ay)*192);
            }
        }
        return out;
    }
};
int main() {
    try {
    const cv::Mat image(480,640,CV_8UC3,cv::Scalar(120,130,140));
    FakeHandModel model;
    for(auto bounds : {std::array<double,4>{200,180,251,263},{0,0,51,83},{589,397,640,480}}) {
        Palm p{};p.box=bounds;p.score=.99;p.id=5;
        const std::array<cv::Point2d,7> shape{{{15,60},{5,30},{20,20},{35,30},{45,45},{5,45},{20,40}}};
        for(int i=0;i<7;++i)p.points[i]={bounds[0]+shape[i].x,bounds[1]+shape[i].y};
        for(bool square : {false,true}) {
            Hand result{};assert(hand(image,p,model,result,square));
            assert(result.crop_side>0 && std::isfinite(result.crop_angle));
            for(auto point:result.xy)assert(std::isfinite(point.x)&&std::isfinite(point.y));
        }
        model.confidence=.79f;Hand rejected{};
        assert(!hand(image,p,model,rejected) && rejected.confidence<.8);
        model.confidence=.8f;Hand boundary{};assert(hand(image,p,model,boundary));
        model.confidence=.95f;
    }
    FakePalmModel palm_model;PalmScanDiagnostics diagnostics;
    const auto selected=palms(image,palm_model,&diagnostics);
    assert(selected.size()==2 && diagnostics.candidates==3 && diagnostics.suppressed==1);
    assert(diagnostics.pairs.size()==1 && diagnostics.max_suppressed_iou>.99);
    assert(diagnostics.max_suppressed_keypoint_distance>10);
    bool invalid=false;
    try {crop_pad(image,{1,1},{1,10},true);} catch(const vision_runtime::InvalidHandCrop&){invalid=true;}
    assert(invalid);
    std::cout<<"PASS: actual OpenCV crop/rotation paths, unchanged confidence rejection, instrumented NMS suppression\n";
    } catch(const std::exception& error) {
        std::cerr<<"FAIL: "<<error.what()<<'\n';return 1;
    }
}
