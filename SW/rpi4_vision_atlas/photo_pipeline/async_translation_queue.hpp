#pragma once
#include "log_record.hpp"
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <functional>
#include <stdexcept>
#include <thread>
#include <utility>

struct TranslationQueueStats {
    std::uint64_t queued=0, delivered=0, failed=0, cancelled=0;
};

class AsyncTranslationQueue {
public:
    using Sender=std::function<bool(const std::string&)>;
    explicit AsyncTranslationQueue(Sender sender,std::size_t capacity=8)
        : sender_(std::move(sender)),capacity_(capacity) {
        if(!sender_ || !capacity_)throw std::invalid_argument("invalid translation queue");
        worker_=std::thread([this]{run();});
    }
    AsyncTranslationQueue(const AsyncTranslationQueue&)=delete;
    AsyncTranslationQueue& operator=(const AsyncTranslationQueue&)=delete;
    ~AsyncTranslationQueue(){stop();}

    // True means queued only. Delivery is reported by [mqtt] published and stats.
    // No sender/network work occurs under this lock or on the calling thread.
    bool enqueueText(const std::string& text) {
        if(text.empty())return false;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if(stopping_ || pending_.size()>=capacity_)return false;
            pending_.push_back(text);++queued_;
        }
        ready_.notify_one();return true;
    }
    TranslationQueueStats stats() const noexcept {
        return {queued_.load(),delivered_.load(),failed_.load(),cancelled_.load()};
    }
    void stop() {
        // Only shutdown waits for an in-flight network call; inference does not.
        std::lock_guard<std::mutex> joining(join_mutex_);
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stopping_=true;cancelled_+=pending_.size();pending_.clear();
        }
        ready_.notify_one();
        if(worker_.joinable())worker_.join();
    }
private:
    void run() noexcept {
        for(;;) {
            std::string text;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                ready_.wait(lock,[this]{return stopping_ || !pending_.empty();});
                if(stopping_)return;
                text=std::move(pending_.front());pending_.pop_front();
            }
            bool delivered=false;
            try { delivered=sender_(text); }
            catch(const std::exception& e) {writeSignLog(std::string("[mqtt] worker exception: ")+e.what()+"\n");}
            catch(...) {writeSignLog("[mqtt] worker exception\n");}
            if(delivered)++delivered_;else ++failed_;
        }
    }
    Sender sender_;
    const std::size_t capacity_;
    std::mutex mutex_,join_mutex_;
    std::condition_variable ready_;
    std::deque<std::string> pending_;
    bool stopping_=false;
    std::atomic<std::uint64_t> queued_{0},delivered_{0},failed_{0},cancelled_{0};
    std::thread worker_;
};
