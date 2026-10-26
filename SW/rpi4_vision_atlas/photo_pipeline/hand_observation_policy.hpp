#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <vector>
#include <stdexcept>

namespace vision_runtime {

class InvalidHandCrop : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

struct HandGeometry {
    std::array<std::array<double, 2>, 21> points{};
};

inline double pointDistance(const std::array<double, 2>& a,
                            const std::array<double, 2>& b) {
    return std::hypot(a[0] - b[0], a[1] - b[1]);
}

inline double palmScale(const HandGeometry& h) {
    return std::max({pointDistance(h.points[0], h.points[9]),
                     pointDistance(h.points[5], h.points[17]), 1.0});
}

// Handedness can flip during occlusion. Never use opposite labels alone as
// evidence of two physical hands. Conversely, close wrists alone are not enough
// to discard two hands whose landmark geometry is genuinely different.
inline bool sameObservedHand(const HandGeometry& a, const HandGeometry& b) {
    const double scale = std::max(palmScale(a), palmScale(b));
    double mean = 0;
    for (std::size_t i = 0; i < a.points.size(); ++i)
        mean += pointDistance(a.points[i], b.points[i]) / a.points.size();
    return pointDistance(a.points[0], b.points[0]) < .25 * scale &&
           mean < .20 * scale;
}

// Shared across tracking, the optional crop retry, and detector fallback.
struct InferenceBudget {
    unsigned hand_calls = 0;
    unsigned palm_calls = 0;
    static constexpr unsigned max_hand_calls = 5;
    bool takeHand() { if (hand_calls >= max_hand_calls) return false; ++hand_calls; return true; }
    bool takePalm() { if (palm_calls) return false; ++palm_calls; return true; }
};

template<class Hand, class Geometry>
void mergeFreshHands(std::vector<Hand>& accepted, const std::vector<Hand>& fresh,
                     Geometry geometry) {
    for (const auto& hand : fresh) {
        if (accepted.size() >= 2) break;
        const bool duplicate = std::any_of(accepted.begin(), accepted.end(),
            [&](const Hand& existing) { return sameObservedHand(geometry(existing), geometry(hand)); });
        if (!duplicate) accepted.push_back(hand);
    }
}

// Exact inverse of resize -> padded crop -> rotation. In particular, an odd
// padding pixel must not be approximated using the clipped box's centre.
inline std::array<double, 2> restoreCropPoint(double model_x, double model_y,
    int padded_side, int bias_x, int bias_y, const std::array<double, 6>& inverse,
    int first_bias_x, int first_bias_y) {
    const double x = model_x * padded_side / 224.0 + bias_x;
    const double y = model_y * padded_side / 224.0 + bias_y;
    return {inverse[0] * x + inverse[1] * y + inverse[2] + first_bias_x,
            inverse[3] * x + inverse[4] * y + inverse[5] + first_bias_y};
}

}  // namespace vision_runtime
