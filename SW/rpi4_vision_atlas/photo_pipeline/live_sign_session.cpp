#include "live_sign_session.hpp"

#include <stdexcept>
#include <iostream>
#include <utility>
#include <cmath>
#include <algorithm>

LiveSignSession::LiveSignSession(
    std::size_t minimum_hand_frames,
    std::size_t maximum_hand_frames,
    std::size_t end_gap_frames
)
    : minimum_hand_frames_(
          minimum_hand_frames
      ),
      maximum_hand_frames_(
          maximum_hand_frames
      ),
      end_gap_frames_(
          end_gap_frames
      ) {
    if (
        minimum_hand_frames_ == 0 ||
        maximum_hand_frames_ <
            minimum_hand_frames_ ||
        end_gap_frames_ == 0
    ) {
        throw std::invalid_argument(
            "Invalid live sign session limits"
        );
    }

    recording_.reserve(
        maximum_hand_frames_ +
        end_gap_frames_
    );
}

bool LiveSignSession::isRecording() const {
    return state_ == State::Recording;
}

void LiveSignSession::resetRecording() {
    recording_.clear();
    observed_hand_frames_ = 0;
    empty_streak_ = 0;
    first_empty_ms_ = -1;
}

std::optional<
    sign_engine::VisionRecordingDetections
> LiveSignSession::finish(
    bool await_release
) {
    const bool accepted =
        observed_hand_frames_ >=
        minimum_hand_frames_;

    {
        std::size_t two_detections = 0;
        for (const auto& frame : recording_) {
            if (frame.size() >= 2) ++two_detections;
        }
        std::cerr << "[sign] " << (accepted ? "completed" : "discarded") << " input=" << recording_.size()
                  << " hand_frames=" << observed_hand_frames_
                  << " two_detections=" << two_detections
                  << " reason=" << (accepted ? finish_reason_ : "TOO_FEW_HAND_FRAMES")
                  << " boundary=" << finish_reason_ << " min=" << minimum_hand_frames_
                  << '\n';
    }

    auto completed =
        std::move(recording_);

    resetRecording();

    state_ = await_release
        ? State::AwaitRelease
        : State::Idle;

    release_empty_streak_ = 0;

    if (!accepted) {
        return std::nullopt;
    }

    return completed;
}

std::optional<
    sign_engine::VisionRecordingDetections
> LiveSignSession::push(
    sign_engine::VisionFrameDetections frame
) {
    const bool has_hands =
        !frame.empty();

    if (state_ == State::AwaitRelease) {
        if (has_hands) {
            release_empty_streak_ = 0;
        } else {
            ++release_empty_streak_;

            if (
                release_empty_streak_ >=
                end_gap_frames_
            ) {
                state_ = State::Idle;
                release_empty_streak_ = 0;
            }
        }

        return std::nullopt;
    }

    if (state_ == State::Idle) {
        if (!has_hands) {
            return std::nullopt;
        }

        state_ = State::Recording;
        resetRecording();
        std::cerr << "[sign] started reason=OBSERVED_HANDS\n";
    }

    recording_.push_back(
        std::move(frame)
    );

    if (has_hands) {
        ++observed_hand_frames_;
        empty_streak_ = 0;

        if (
            observed_hand_frames_ >=
            maximum_hand_frames_
        ) {
            return finish(
                true
            );
        }

        return std::nullopt;
    }

    ++empty_streak_;

    if (empty_streak_ < end_gap_frames_) {
        return std::nullopt;
    }

    recording_.resize(
        recording_.size() -
        empty_streak_
    );

    return finish(
        false
    );
}

std::optional<sign_engine::VisionRecordingDetections> LiveSignSession::push(
    sign_engine::VisionFrameDetections frame, double capture_ms,
    bool recovering_second_hand) {
    if (!std::isfinite(capture_ms) || capture_ms < last_capture_ms_)
        throw std::invalid_argument("Non-monotonic sign capture time");
    // Estimate cadence before a missing run, then freeze it during that run.
    // A long absence must not inflate its own timeout. The 1500ms cap bounds
    // the sampling allowance to 2250ms even after a camera/worker stall.
    if (last_capture_ms_ >= 0 && first_empty_ms_ < 0 &&
        capture_ms > last_capture_ms_) {
        capture_intervals_ms_[capture_interval_index_++ % capture_intervals_ms_.size()] =
            std::min(1500.0, capture_ms - last_capture_ms_);
    }
    last_capture_ms_ = capture_ms;
    const bool has_hands = !frame.empty();
    if (state_ == State::AwaitRelease) {
        if (has_hands) release_start_ms_ = -1;
        else if (release_start_ms_ < 0) release_start_ms_ = capture_ms;
        else if (capture_ms - release_start_ms_ >= 350) {
            state_ = State::Idle;
            release_start_ms_ = -1;
        }
        return std::nullopt;
    }

    std::optional<sign_engine::VisionRecordingDetections> completed;
    // Keep the original fast-camera limits, but allow one missed observation
    // at a slow irregular inference cadence without fabricating hand frames.
    const double cadence = *std::max_element(capture_intervals_ms_.begin(), capture_intervals_ms_.end());
    const double gap_limit = std::max(recovering_second_hand ? 650.0 : 350.0, 1.5 * cadence);
    if (state_ == State::Recording && first_empty_ms_ >= 0 &&
        capture_ms - first_empty_ms_ >= gap_limit) {
        recording_.resize(recording_.size() - empty_streak_);
        finish_reason_ = recovering_second_hand ? "RECOVERY_TIME_LIMIT" : "EMPTY_TIME_GAP";
        completed = finish(false);
    }
    if (state_ == State::Idle) {
        if (!has_hands) return completed;
        state_ = State::Recording;
        resetRecording();
        std::cerr << "[sign] started reason=OBSERVED_HANDS capture_ms=" << capture_ms << '\n';
    }
    recording_.push_back(std::move(frame));
    if (has_hands) {
        ++observed_hand_frames_;
        empty_streak_ = 0;
        first_empty_ms_ = -1;
        if (observed_hand_frames_ >= maximum_hand_frames_) {
            finish_reason_ = "MAX_OBSERVED_FRAMES";
            return finish(true);
        }
    } else {
        if (!empty_streak_) first_empty_ms_ = capture_ms;
        ++empty_streak_;
    }
    return completed;
}

std::optional<
    sign_engine::VisionRecordingDetections
> LiveSignSession::flush() {
    finish_reason_ = "FLUSH";
    if (state_ != State::Recording) {
        state_ = State::Idle;
        release_empty_streak_ = 0;

        return std::nullopt;
    }

    while (
        !recording_.empty() &&
        recording_.back().empty()
    ) {
        recording_.pop_back();
    }

    return finish(
        false
    );
}
