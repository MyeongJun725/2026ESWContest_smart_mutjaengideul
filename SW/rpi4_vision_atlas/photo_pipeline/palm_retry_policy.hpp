#pragma once

#include <cstddef>

namespace vision_runtime {

// `any_failure` from a full palm scan also includes rejected false candidates.
// Accepted hand ROIs are still usable. A full scan with successful hands must
// not repeatedly schedule itself just because another candidate was rejected.
constexpr bool forcePalmAfterInference(
    bool used_palm_detector,
    bool any_failure,
    std::size_t accepted_hands,
    bool near_border
) noexcept {
    return accepted_hands == 0 || near_border ||
           (!used_palm_detector && any_failure);
}

// After two failed two-hand tracking attempts, bypass tracking for three
// processed frames. Full palm inference still runs on every bypassed frame;
// no stale landmarks or interpolated detections are returned. Retry tracking
// after the bounded window, and return to normal as soon as it succeeds.
class TwoHandTrackingBackoff {
public:
    bool beginFrame() noexcept {
        if (remaining_ == 0) return false;
        --remaining_;
        return true;
    }

    void observe(bool attempted_tracking, bool tracking_failed,
                 std::size_t previous_tracks,
                 std::size_t accepted_hands) noexcept {
        if (previous_tracks < 2 || accepted_hands < 2) {
            reset();
            return;
        }
        if (!attempted_tracking) return;
        if (!tracking_failed) {
            reset();
            return;
        }
        if (failures_ < 2) ++failures_;
        if (failures_ >= 2) remaining_ = 3;
    }

private:
    void reset() noexcept { failures_ = 0; remaining_ = 0; }
    unsigned failures_ = 0;
    unsigned remaining_ = 0;
};


// Bounded re-acquisition after a real two-hand -> one-hand loss. A successful
// one-hand tracker otherwise cannot discover the missing second hand until
// the normal scheduled scan. Request at most four scans in 1200ms, separated
// by at least 200ms of capture time, rather than exhausting retries at high FPS;
// never reuse old landmarks and never loop on rejected palm candidates.
class LostSecondHandRecovery {
public:
    bool beginFrame(double now_ms) noexcept {
        if (!recovering(now_ms) || attempts_ >= 4 || now_ms < next_ms_) return false;
        ++attempts_;
        next_ms_ = now_ms + 200;
        return true;
    }
    void observe(std::size_t previous_tracks, std::size_t accepted_hands,
                 double now_ms) noexcept {
        if (accepted_hands >= 2) {
            deadline_ms_ = -1;
        } else if (previous_tracks >= 2 && deadline_ms_ < now_ms) {
            deadline_ms_ = now_ms + 1200;
            next_ms_ = now_ms;
            attempts_ = 0;
        }
    }
    bool recovering(double now_ms) const noexcept {
        return deadline_ms_ >= now_ms;
    }
private:
    unsigned attempts_ = 0;
    double deadline_ms_ = -1, next_ms_ = 0;
};

}  // namespace vision_runtime
