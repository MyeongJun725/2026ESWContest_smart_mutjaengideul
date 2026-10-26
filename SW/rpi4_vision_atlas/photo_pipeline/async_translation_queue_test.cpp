#include "async_translation_queue.hpp"
#include <cassert>
#include <chrono>
#include <future>
#include <iostream>
#include <vector>
using namespace std::chrono_literals;
int main(){
    {
        std::mutex mutex;std::condition_variable changed;bool entered=false,release=false;
        std::vector<std::string> sent;const auto caller=std::this_thread::get_id();
        AsyncTranslationQueue queue([&](const std::string& text){
            assert(std::this_thread::get_id()!=caller);
            std::unique_lock<std::mutex> lock(mutex);entered=true;changed.notify_all();
            changed.wait(lock,[&]{return release;});sent.push_back(text);changed.notify_all();return true;
        });
        assert(queue.enqueueText("구조"));
        {std::unique_lock<std::mutex> lock(mutex);assert(changed.wait_for(lock,2s,[&]{return entered;}));}
        const auto begin=std::chrono::steady_clock::now();
        assert(queue.enqueueText("쓰러지다"));
        for(int i=0;i<7;++i)assert(queue.enqueueText(std::to_string(i)));
        assert(!queue.enqueueText("queue-full"));
        assert(!queue.enqueueText(""));
        assert(std::chrono::steady_clock::now()-begin<200ms);
        // The sender is still blocked, yet the inference-side work can continue.
        std::size_t simulated_frames=0;for(int i=0;i<10000;++i)++simulated_frames;
        assert(simulated_frames==10000&&queue.stats().delivered==0);
        {std::lock_guard<std::mutex> lock(mutex);release=true;}changed.notify_all();
        {std::unique_lock<std::mutex> lock(mutex);assert(changed.wait_for(lock,2s,[&]{return sent.size()==9;}));}
        queue.stop();assert(queue.stats().delivered==9&&queue.stats().failed==0);
        assert(sent[0]=="구조"&&sent[1]=="쓰러지다");
        std::cout<<"PASS: blocked sender does not block enqueue/inference; bounded FIFO; UTF-8 text preserved\n";
    }
    {
        std::atomic<unsigned> calls{0};std::promise<void> finished;
        AsyncTranslationQueue queue([&](const std::string& text){
            ++calls;
            if(text=="exception")throw std::runtime_error("test sender");
            if(text=="last")finished.set_value();
            return false;
        });
        assert(queue.enqueueText("exception"));assert(queue.enqueueText("last"));
        assert(finished.get_future().wait_for(2s)==std::future_status::ready);
        queue.stop();assert(calls==2&&queue.stats().failed==2&&queue.stats().delivered==0);
        std::cout<<"PASS: send failure/exception remains on worker; queued does not mean delivered\n";
    }
    {
        std::promise<void> entered,release;auto can_finish=release.get_future().share();
        AsyncTranslationQueue queue([&](const std::string&){entered.set_value();can_finish.wait();return true;});
        assert(queue.enqueueText("in-flight"));assert(entered.get_future().wait_for(2s)==std::future_status::ready);
        assert(queue.enqueueText("pending1"));assert(queue.enqueueText("pending2"));
        auto stopped=std::async(std::launch::async,[&]{queue.stop();});
        const auto deadline=std::chrono::steady_clock::now()+2s;
        while(queue.stats().cancelled!=2&&std::chrono::steady_clock::now()<deadline)std::this_thread::yield();
        assert(queue.stats().cancelled==2&&!queue.enqueueText("after-stop"));
        release.set_value();assert(stopped.wait_for(2s)==std::future_status::ready);stopped.get();
        assert(queue.stats().delivered==1);queue.stop();
        std::cout<<"PASS: shutdown cancels pending queue and safely joins in-flight sender\n";
    }
}
