#include "active_targets.hpp"
#include "temporal_resample.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <limits>
#include <map>
#include <stdexcept>
namespace sign_engine {
namespace {
constexpr std::size_t kFrames=80,kDims=168;
constexpr std::array<int,10> kClasses{{0,1,3,4,5,6,9,12,14,15}};
template<class T> T read(std::ifstream& f) {
 T value{};f.read(reinterpret_cast<char*>(&value),sizeof(value));
 if(!f)throw std::runtime_error("active target model truncated");return value;
}
}
ActiveTargetModel loadActiveTargetModel(const std::string& path) {
 // Deployed ARM64 and the offline build both use IEEE754 little-endian floats.
 const std::uint32_t endian=1;
 if(*reinterpret_cast<const unsigned char*>(&endian)!=1 || sizeof(float)!=4)
  throw std::runtime_error("active target model requires little endian float32");
 std::ifstream f(path,std::ios::binary);
 if(!f)throw std::runtime_error("cannot open active target model: "+path);
 char magic[8];f.read(magic,8);
 if(!f || std::string(magic,8)!=std::string("SGTACT4\0",8))throw std::runtime_error("active target model magic");
 const auto version=read<std::uint32_t>(f),n=read<std::uint32_t>(f),t=read<std::uint32_t>(f),d=read<std::uint32_t>(f);
 if(version!=1 || n<30 || n>512 || t!=kFrames || d!=kDims)throw std::runtime_error("active target model dimensions");
 ActiveTargetModel model;std::map<int,int> counts;
 for(std::uint32_t i=0;i<n;++i){
  ActiveTargetReference ref;ref.id=read<std::int32_t>(f);
  if(std::find(kClasses.begin(),kClasses.end(),ref.id)==kClasses.end())throw std::runtime_error("active target model class");
  ref.feature.resize(t*d);f.read(reinterpret_cast<char*>(ref.feature.data()),t*d*sizeof(float));
  if(!f || !std::all_of(ref.feature.begin(),ref.feature.end(),[](float x){return std::isfinite(x);}))throw std::runtime_error("active target model feature");
  ++counts[ref.id];model.references.push_back(std::move(ref));
 }
 for(int id:kClasses)if(counts[id]<3)throw std::runtime_error("active target model class coverage");
 if(f.peek()!=std::char_traits<char>::eof())throw std::runtime_error("active target model trailing data");
 return model;
}
SignRecognitionResult classifyWithActiveTargets(const RecordingFrames& frames,
 const RuntimeData& runtime,const ActiveTargetModel& model,ActiveTargetDiagnostics& diag) {
 diag=ActiveTargetDiagnostics{};
 auto baseline=classifyRecording(frames,runtime);
 // Never let KEEP_ONEHAND or the target override bypass the coverage guard.
 if(baseline.stage=="INCOMPLETE_TWO_HAND_TRACK"){
  diag.reason="INCOMPLETE_TWO_HAND_TRACK";return baseline;
 }
 const auto stats=analyzeRecordingFrames(frames);diag.paired_frames=stats.both_count;
 // WORD1229 has a supporting hand that can remain almost stationary. The
 // motion-ratio router may call this one-hand even when both hands were seen.
 // Only reconsider that result with sustained real paired observations and
 // an unambiguous WORD1229 reference match; never manufacture the missing hand.
 const bool onehand_baseline=baseline.valid && baseline.usage_type==UsageType::OneHand;
 if(onehand_baseline && (stats.both_count<20 || stats.both_ratio<.60)){
  diag.reason="KEEP_ONEHAND_PAIR_COVERAGE";return baseline;
 }
 if(stats.both_count<10 || stats.both_ratio<.35){diag.reason="PAIR_COVERAGE";return baseline;}
 HandSequence left,right;
 for(const auto& frame:frames)if(frame.has_left && frame.has_right){left.push_back(frame.left);right.push_back(frame.right);}
 try {
  FeatureV3Options opts;opts.one_hand_ratio_threshold=0;opts.no_motion_threshold=0;
  opts.anchor_frame_count=5;opts.canonical_hand=CanonicalHand::Right;
  const auto raw=buildHandFeaturesV3(&left,&right,opts);
  diag.left_motion=raw.usage.left_score;diag.right_motion=raw.usage.right_score;
  if(std::max(diag.left_motion,diag.right_motion)<.5){diag.reason="INSUFFICIENT_MOTION";return baseline;}
  const auto feature=temporalResample(raw.features,raw.frame_count,172,80);
  std::map<int,double> scores;for(int c:kClasses)scores[c]=std::numeric_limits<double>::infinity();
  for(const auto& ref:model.references){double sum=0;
   for(std::size_t t=0;t<kFrames;++t)for(std::size_t j=0;j<kDims;++j){
    const double delta=double(feature[t*172+j])-double(ref.feature[t*kDims+j]);
    sum+=(j<84?.25:.75)*delta*delta;
   }
   scores[ref.id]=std::min(scores[ref.id],std::sqrt(sum/(kFrames*kDims)));
  }
  std::vector<std::pair<double,int>> ranking;for(const auto& s:scores)ranking.emplace_back(s.second,s.first);
  std::sort(ranking.begin(),ranking.end());
  diag.evaluated=true;diag.candidate=ranking[0].second;diag.distance=ranking[0].first;diag.runner_up=ranking[1].first;
  if(onehand_baseline && diag.candidate!=15){diag.reason="KEEP_ONEHAND_OTHER_TARGET";return baseline;}
  if(diag.candidate!=5 && diag.candidate!=15){diag.reason="OTHER_CLASS_NEAREST";return baseline;}
  if(diag.candidate==15 && stats.both_count<20){diag.reason="WORD1229_PAIR_COVERAGE";return baseline;}
  if(diag.candidate!=15 && std::min(diag.left_motion,diag.right_motion)<.5){diag.reason="INSUFFICIENT_MOTION";return baseline;}
  if(diag.distance>.45 || diag.distance>.80*diag.runner_up){diag.reason="AMBIGUOUS_OR_DISTANT";return baseline;}
  diag.accepted=true;diag.reason="ACCEPTED";
  SignRecognitionResult result;result.status=SignRuntimeStatus::Success;result.valid=true;
  result.final_id=diag.candidate;result.stage="TWOHAND_ACTIVE_TARGET_K1";
  result.usage_type=UsageType::TwoHand;result.recording_stats=stats;
  result.source_mode="BOTH_ALIGNED";result.selected_frames=stats.both_count;
  result.raw_feature=raw;result.feature80=feature;result.twohand_ran=true;
  result.twohand_result.final_id=diag.candidate;result.twohand_result.stage=result.stage;
  for(const auto& r:ranking){ClassScore c;c.class_id=r.second;c.score=r.first;result.twohand_result.base_ranking.push_back(c);}
  return result;
 } catch(const std::exception& e){diag.reason=std::string("ACTIVE_ERROR:")+e.what();return baseline;}
}
} // namespace sign_engine
