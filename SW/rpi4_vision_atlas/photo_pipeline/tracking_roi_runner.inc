#include "hand_observation_policy.hpp"

vision_runtime::HandGeometry hand_geometry(const Hand& hand_result) {
    vision_runtime::HandGeometry geometry;
    for (std::size_t i = 0; i < 21; ++i)
        geometry.points[i] = {hand_result.xy[i].x, hand_result.xy[i].y};
    return geometry;
}

void note_hand_candidate(vision_runtime::TrackingRoiRetryDiagnostics& diagnostics,
                         const Palm& palm, const Hand& result, bool accepted,
                         bool square_retry) {
    diagnostics.candidates.push_back({palm.id, result.confidence, result.crop_angle,
        result.crop_box, result.palm_points_outside_crop, accepted, square_retry, result.invalid_crop});
}

bool infer_hand_candidate(const cv::Mat& image, const Palm& palm, Model& model,
                          Hand& result, bool square_retry = false) {
    try { return hand(image, palm, model, result, square_retry); }
    catch (const vision_runtime::InvalidHandCrop&) {
        // A bad ROI must not terminate the camera or discard a good sibling.
        result.invalid_crop = true;
        return false;
    }
}

std::vector<Hand> run_hands(const cv::Mat& image,
                            const std::vector<Palm>& palms_to_run,
                            Model& hand_model,
                            bool& any_failure,
                            bool tracking,
                            vision_runtime::TrackingRoiRetryDiagnostics& retry,
                            vision_runtime::InferenceBudget* frame_budget = nullptr) {
    vision_runtime::InferenceBudget local_budget;
    auto& budget = frame_budget ? *frame_budget : local_budget;
    // Finish all original crops first. Preserve every originally accepted hand.
    std::vector<Hand> slots(palms_to_run.size());
    std::vector<bool> accepted(palms_to_run.size(), false);
    for (std::size_t i=0; i<palms_to_run.size(); ++i) {
        if (!budget.takeHand()) break;
        accepted[i] = infer_hand_candidate(image, palms_to_run[i], hand_model, slots[i]);
        if (accepted[i]) for (std::size_t j=0; j<i; ++j) {
            if (accepted[j] && vision_runtime::sameObservedHand(
                    hand_geometry(slots[i]), hand_geometry(slots[j])))
                accepted[i] = false;
        }
        note_hand_candidate(retry, palms_to_run[i], slots[i], accepted[i], false);
        if (std::count(accepted.begin(), accepted.end(), true) >= 2) break;
    }
    for (std::size_t i=0; i<palms_to_run.size(); ++i) {
        const auto& palm = palms_to_run[i];
        if (accepted[i] || !vision_runtime::eligibleTrackingRoiRetry(
                tracking, palms_to_run.size(), palm.tracked_side,
                slots[i].confidence, retry.attempted)) continue;
        if (!budget.takeHand()) break;
        ++retry.attempted;
        Hand candidate{};
        const bool fresh = infer_hand_candidate(image, palm, hand_model, candidate, true);
        const double span = std::max(palm.box[2]-palm.box[0], palm.box[3]-palm.box[1]);
        bool duplicate=false;
        if (fresh) for (std::size_t j=0; j<slots.size(); ++j) {
            if (j!=i && accepted[j] && cv::norm(candidate.xy[0]-slots[j].xy[0])<.25*span)
                duplicate=true;
        }
        const double distance = fresh ? cv::norm(cv::Point2d(candidate.xy[0])-palm.points[0]) : 0;
        const bool in_image = fresh && candidate.xy[0].x>=0 && candidate.xy[0].x<image.cols &&
            candidate.xy[0].y>=0 && candidate.xy[0].y<image.rows;
        const char* reason = vision_runtime::trackingRoiRetryRejection(
            candidate.confidence, candidate.handedness, palm.tracked_side,
            distance, span, in_image, duplicate);
        const bool keep = fresh && reason==nullptr;
        note_hand_candidate(retry, palm, candidate, keep, true);
        std::cout << "[roi-retry] original=" << slots[i].confidence
                  << " square=" << candidate.confidence
                  << " accepted=" << (keep?1:0)
                  << " reason=" << (reason?reason:"ACCEPTED") << '\n';
        if (keep) { slots[i]=candidate; accepted[i]=true; ++retry.accepted; }
        break; // bounded to one extra model inference per processed frame.
    }
    std::vector<Hand> results;
    any_failure=false;
    for (std::size_t i=0; i<slots.size(); ++i) {
        if (accepted[i] && results.size()<2) results.push_back(slots[i]);
        else if (!accepted[i]) any_failure=true;
    }
    return results;
}
