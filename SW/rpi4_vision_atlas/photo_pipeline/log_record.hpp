#pragma once
#include <cerrno>
#include <mutex>
#include <string>
#ifdef _WIN32
#include <io.h>
#else
#include <unistd.h>
#endif

// Write complete records so the network worker cannot split a recognition line.
inline std::mutex sign_log_mutex;
inline void writeSignLog(const std::string& record) noexcept {
    std::lock_guard<std::mutex> lock(sign_log_mutex);
    std::size_t offset=0;
    while(offset<record.size()) {
#ifdef _WIN32
        const auto n=::_write(2,record.data()+offset,
            static_cast<unsigned>(record.size()-offset));
#else
        const auto n=::write(STDERR_FILENO,record.data()+offset,record.size()-offset);
#endif
        if(n<0 && errno==EINTR)continue;
        if(n<=0)break;
        offset+=static_cast<std::size_t>(n);
    }
}
