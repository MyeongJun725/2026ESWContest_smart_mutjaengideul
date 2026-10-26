#include "palm_retry_policy.hpp"
#include <iostream>
#include <stdexcept>

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

int main() {
    using vision_runtime::forcePalmAfterInference;

    // Regression: two real hands plus a rejected false palm candidate. The
    // former `failure || empty || border` expression scans on all 20 frames.
    bool forced = true;
    int palm_scans = 0;
    for (int frame = 0; frame < 20; ++frame) {
        const bool scan = forced || frame % 10 == 0;
        if (scan) ++palm_scans;
        const bool rejected_false_candidate = scan;
        forced = forcePalmAfterInference(scan, rejected_false_candidate, 2, false);
    }
    require(palm_scans == 2, "False candidate kept forcing palm scans");

    require(forcePalmAfterInference(true, true, 0, false),
            "Empty detector result must trigger another scan");
    require(forcePalmAfterInference(false, false, 2, true),
            "Border recovery must remain enabled");
    require(forcePalmAfterInference(false, true, 1, false),
            "Unresolved tracking failure must request recovery");
    require(!forcePalmAfterInference(true, true, 1, false),
            "Accepted single hand was discarded due to a false candidate");
    require(!forcePalmAfterInference(false, false, 2, false),
            "Healthy two-hand tracking must continue");

    vision_runtime::TwoHandTrackingBackoff backoff;
    require(!backoff.beginFrame(), "Healthy tracking started in backoff");
    backoff.observe(true, true, 2, 2);
    require(!backoff.beginFrame(), "One failure must not trigger backoff");
    // A scheduled full scan (even with false candidates) is not a tracking
    // failure and must not be counted as one.
    backoff.observe(false, true, 2, 2);
    require(!backoff.beginFrame(), "Scheduled full scan triggered backoff");
    backoff.observe(true, true, 2, 2);
    for (int i = 0; i < 3; ++i) {
        require(backoff.beginFrame(), "Repeated failures did not bypass tracking");
        backoff.observe(false, false, 2, 2);
    }
    require(!backoff.beginFrame(), "Backoff never retried tracking");
    backoff.observe(true, false, 2, 2);
    backoff.observe(true, true, 2, 2);
    require(!backoff.beginFrame(), "Successful tracking did not reset failure history");
    backoff.observe(true, true, 2, 2);
    require(backoff.beginFrame(), "Second failure did not restart backoff");
    backoff.observe(false, false, 2, 1);
    require(!backoff.beginFrame(), "Single-hand input kept two-hand backoff active");
    for (int i = 0; i < 20; ++i) {
        backoff.observe(true, true, 1, 1);
        require(!backoff.beginFrame(), "Single-hand failures triggered two-hand backoff");
    }
    backoff.observe(true, true, 2, 2);
    backoff.observe(true, true, 2, 2);
    backoff.observe(false, false, 2, 0);
    require(!backoff.beginFrame(), "Empty detection did not reset backoff");
    int probes = 0;
    for (int i = 0; i < 20; ++i) {
        const bool direct = backoff.beginFrame();
        if (!direct) ++probes;
        backoff.observe(!direct, !direct, 2, 2);
    }
    require(probes == 6, "Persistent-failure probe budget regression");
    vision_runtime::LostSecondHandRecovery recovery;
    for(int i=0;i<25;++i){require(!recovery.beginFrame(i*40),"normal one hand recovery");recovery.observe(1,1,i*40);}
    recovery.observe(2,1,1000);
    int scans=0;
    for(int i=0;i<40;++i){double ms=1000+i*40;scans+=recovery.beginFrame(ms)?1:0;recovery.observe(1,1,ms);}
    require(scans==4,"timed recovery must be bounded to four scans");
    recovery.observe(2,0,3000);
    require(recovery.beginFrame(3000),"total loss must retain a bounded search");
    recovery.observe(0,2,3100);
    require(!recovery.beginFrame(3200),"fresh two hand success must stop recovery");
    std::cout << "PASS: bounded two-hand tracking backoff, recovery, single-hand isolation\n";

    std::cout << "PASS: false detector candidates do not cause repeated scans; "
                 "scheduled scans, empty and border recovery remain enabled\n";
}
