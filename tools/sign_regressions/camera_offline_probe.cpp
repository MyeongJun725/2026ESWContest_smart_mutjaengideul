// Offline diagnostics only: no camera, ONNX, MQTT, serial or device access.
// Timing covers classifyRecording(), not camera preprocessing or model inference.
#include "sign_runtime.hpp"
#include "live_sign_session.hpp"
#include <algorithm>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using namespace sign_engine;

HandSequence readHands(const std::string& path) {
    constexpr std::size_t frames = 87;
    std::vector<float> values(frames * 21 * 2);
    std::ifstream input(path, std::ios::binary);
    if (!input.read(reinterpret_cast<char*>(values.data()), values.size()*sizeof(float)) ||
        input.peek() != std::char_traits<char>::eof())
        throw std::runtime_error("Unexpected fixture size: " + path);
    HandSequence hands(frames);
    for (std::size_t f=0; f<frames; ++f)
        for (std::size_t k=0; k<21; ++k)
            hands[f].points[k] = {values[(f*21+k)*2], values[(f*21+k)*2+1]};
    return hands;
}

int main(int argc, char** argv) {
    try {
        if (argc!=2) throw std::runtime_error("Usage: camera_offline_probe REPO_ROOT");
        const std::string root=argv[1];
        const auto runtime=loadRuntimeData(root+"/SW/rpi4_sign_cpp/runtime_data");
        const std::string fixture=root+"/SW/rpi4_sign_cpp/tests/fixtures/sign_runtime_routes_frozen/";
        const auto left=readHands(fixture+"input_real01_left_87x21x2.bin");
        const auto right=readHands(fixture+"input_real01_right_87x21x2.bin");
        std::vector<std::pair<std::string, RecordingFrames>> cases;
        RecordingFrames original;
        for (std::size_t i=0;i<left.size();++i) {
            FrameHands frame; frame.has_left=frame.has_right=true;
            frame.left=left[i]; frame.right=right[i]; original.push_back(frame);
        }
        cases.push_back({"original_two_hand_fixture", original});
        cases.push_back({"empty_recording", {}});
        // These stationary inputs are constructed from sign landmarks, not idle-camera ground truth.
        for (std::size_t sample : {std::size_t(0), std::size_t(43), std::size_t(86)})
            for (bool use_left : {true,false}) {
                FrameHands frame;frame.has_left=use_left;frame.has_right=!use_left;
                frame.left=left[sample];frame.right=right[sample];
                cases.push_back({std::string("stationary_")+(use_left?"left_":"right_")+
                    std::to_string(sample), RecordingFrames(90,frame)});
            }
        for (const auto& item : cases) {
            const auto expected=classifyRecording(item.second,runtime);
            for (int i=0;i<3;++i) classifyRecording(item.second,runtime);
            std::vector<double> elapsed;
            for (int i=0;i<30;++i) {
                const auto start=std::chrono::steady_clock::now();
                const auto result=classifyRecording(item.second,runtime);
                elapsed.push_back(std::chrono::duration<double,std::milli>(
                    std::chrono::steady_clock::now()-start).count());
                if (result.final_id!=expected.final_id || result.stage!=expected.stage ||
                    result.valid!=expected.valid || result.is_nosign!=expected.is_nosign)
                    throw std::runtime_error("Non-deterministic classifier result");
            }
            std::sort(elapsed.begin(),elapsed.end());
            std::cout<<std::fixed<<std::setprecision(4)
                <<"{\"case\":"<<std::quoted(item.first)<<",\"frames\":"<<item.second.size()
                <<",\"valid\":"<<(expected.valid?"true":"false")<<",\"id\":"<<expected.final_id
                <<",\"nosign\":"<<(expected.is_nosign?"true":"false")
                <<",\"stage\":"<<std::quoted(expected.stage)
                <<",\"runs\":30,\"p50_ms\":"<<elapsed[14]<<",\"p95_ms\":"<<elapsed[28]
                <<",\"max_ms\":"<<elapsed.back()<<"}\n";
        }
        for (bool held : {false,true}) {
            // Match vision_stream_sign_decoupled.cpp's live recording limits.
            LiveSignSession session(10,90,5);
            unsigned completed=0;
            VisionHandDetection detection;detection.confidence=.99;detection.landmarks=right[43];
            for (int i=0;i<900;++i)
                if (session.push(held?VisionFrameDetections{detection}:VisionFrameDetections{},
                                 i*(1000.0/30),false)) ++completed;
            std::cout<<"{\"session\":"<<std::quoted(held?"held_hand_30_seconds":"no_hands_30_seconds")
                <<",\"completed\":"<<completed<<",\"recording\":"
                <<(session.isRecording()?"true":"false")<<"}\n";
            if (completed!=(held?1u:0u)) throw std::runtime_error("Unexpected session count");
        }
    } catch (const std::exception& error) {
        std::cerr<<error.what()<<'\n';return 1;
    }
}
