#pragma once
#include <cmath>
#include <cstddef>
#include <array>
#include <vector>

namespace vision_runtime {
struct HandCandidateDiagnostic {
    int anchor = -1;
    double confidence = 0, angle = 0;
    std::array<int,4> crop{};
    int outside = 0;
    bool accepted = false, square_retry = false;
    bool invalid_crop = false;
};
struct TrackingRoiRetryDiagnostics {
    unsigned attempted=0, accepted=0;
    std::vector<HandCandidateDiagnostic> candidates;
};

// Retry only established two-hand tracking. One retry at most per processed frame.
// Very low model scores use the existing full-detector fallback immediately.
inline bool eligibleTrackingRoiRetry(bool tracking, std::size_t inputs,
    int previous_side, double original_confidence, unsigned attempted) noexcept {
    return tracking && inputs==2 && (previous_side==1 || previous_side==-1) &&
        attempted==0 && std::isfinite(original_confidence) &&
        original_confidence>=.2 && original_confidence<.8;
}

// This is fresh inference on this frame, never reuse/interpolate a past hand.
// The 0.8 hand threshold is unchanged. Extra checks constrain association to
// the previous physical side and plausible wrist motion around that track.
inline const char* trackingRoiRetryRejection(double confidence, double raw,
    int previous_side, double wrist_distance, double palm_span,
    bool wrist_in_image, bool duplicates_other_hand) noexcept {
    if(!std::isfinite(confidence) || confidence<.8) return "LOW_CONFIDENCE";
    if(!std::isfinite(raw) || raw<0 || raw>1 ||
       (raw>.5?1:-1)!=previous_side) return "SIDE_CHANGED";
    if(!std::isfinite(wrist_distance) || !std::isfinite(palm_span) ||
       palm_span<=0 || wrist_distance>palm_span || !wrist_in_image) return "WRIST_MOVED";
    if(duplicates_other_hand) return "DUPLICATE_WRIST";
    return nullptr;
}
} // namespace vision_runtime
