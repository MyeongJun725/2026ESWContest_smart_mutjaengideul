#pragma once
#include "sign_types.hpp"
#include <algorithm>
#include <cmath>

namespace sign_engine {
struct HandCoverageQuality {
    std::size_t paired = 0, contact = 0, longest_pair_streak = 0;
    std::size_t trailing_single = 0, longest_single_after_contact = 0, observed = 0;
    bool incomplete_contact_sequence = false;
};

inline double landmarkDistance(const Point2f& a, const Point2f& b) {
    return std::hypot(a.x-b.x, a.y-b.y);
}

inline HandCoverageQuality assessHandCoverage(const RecordingFrames& frames) {
    HandCoverageQuality quality;
    std::size_t streak=0, empty_streak=0;
    for (const auto& frame : frames) {
        if (!frame.has_left && !frame.has_right) {
            streak=0;
            if (++empty_streak>=5) quality = {};
            continue;
        }
        empty_streak=0;
        ++quality.observed;
        if (frame.has_left && frame.has_right) {
            ++quality.paired;
            quality.longest_pair_streak=std::max(quality.longest_pair_streak, ++streak);
            quality.trailing_single=0;
            const auto& left=frame.left.points;
            const auto& right=frame.right.points;
            const double scale=std::max({landmarkDistance(left[0],left[9]),
                landmarkDistance(right[0],right[9]), 1e-6});
            double nearest=1e9;
            for (int i : {0,4,8,12,16,20})
                for (int j : {0,5,9,13,17})
                    nearest=std::min({nearest, landmarkDistance(left[i],right[j]),
                        landmarkDistance(right[i],left[j])});
            if (nearest < .65*scale) ++quality.contact;
        } else {
            streak=0;
            ++quality.trailing_single;
            if (quality.contact>=3 && quality.longest_pair_streak>=3)
                quality.longest_single_after_contact=std::max(
                    quality.longest_single_after_contact, quality.trailing_single);
        }
    }
    // A brief, distant supporting hand is not a reason to reject one-hand
    // signs. Require sustained two-hand contact followed by severe loss.
    // Do not override established long paired sequences or the existing TEMP
    // rescue route. This guard addresses clips with insufficient paired data.
    // A single reacquired pair must not erase a preceding severe loss run.
    quality.incomplete_contact_sequence = quality.paired<20 && quality.longest_pair_streak>=3 &&
        quality.contact>=3 && quality.longest_single_after_contact>=8 && quality.observed>0 &&
        double(quality.paired)/quality.observed < .35;
    return quality;
}
}  // namespace sign_engine
