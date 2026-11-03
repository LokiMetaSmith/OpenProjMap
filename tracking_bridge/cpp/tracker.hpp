#pragma once

#include <cstdint>
#include <vector>
#include <string>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>

namespace openprojmap {

#pragma pack(push, 1)
struct TouchPacket {
    uint8_t cmd;      // 1 = down, 2 = up, 3 = move
    uint8_t touch_id; // 0..255
    float x;          // Big-endian float 32
    float y;          // Big-endian float 32
};
#pragma pack(pop)

inline float htonf(float val) {
    union { float f; uint32_t u; } in, out;
    in.f = val;
    out.u = htonl(in.u);
    return out.f;
}

class UDPEmitter {
public:
    UDPEmitter(const std::string& ip = "127.0.0.1", int port = 9000)
        : ip_(ip), port_(port), sock_(-1) {
        init();
    }

    ~UDPEmitter() {
        if (sock_ >= 0) {
            close(sock_);
        }
    }

    bool sendTouch(uint8_t cmd, uint8_t touch_id, float x, float y) {
        if (sock_ < 0) return false;
        TouchPacket pkt;
        pkt.cmd = cmd;
        pkt.touch_id = touch_id;
        pkt.x = htonf(x);
        pkt.y = htonf(y);

        ssize_t sent = sendto(sock_, &pkt, sizeof(pkt), 0,
                              (struct sockaddr*)&addr_, sizeof(addr_));
        return sent == sizeof(pkt);
    }

private:
    void init() {
        sock_ = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock_ < 0) return;
        addr_.sin_family = AF_INET;
        addr_.sin_port = htons(port_);
        inet_pton(AF_INET, ip_.c_str(), &addr_.sin_addr);
    }

    std::string ip_;
    int port_;
    int sock_;
    struct sockaddr_in addr_;
};

struct DetectedPoint {
    uint8_t id;
    float x;
    float y;
};

class FastBlobDetector {
public:
    FastBlobDetector(float min_area = 5.0f) : min_area_(min_area) {}

    // Processes a grayscale or thresholded buffer and extracts bright spot centroids
    std::vector<DetectedPoint> processThresholded(const uint8_t* data, int width, int height) {
        std::vector<DetectedPoint> results;
        if (!data || width <= 0 || height <= 0) return results;

        // Fast 1D run-length connected component centroid accumulator
        double sum_x = 0.0, sum_y = 0.0;
        int count = 0;

        for (int y = 0; y < height; ++y) {
            const uint8_t* row = data + y * width;
            for (int x = 0; x < width; ++x) {
                if (row[x] > 200) { // High threshold
                    sum_x += x;
                    sum_y += y;
                    count++;
                }
            }
        }

        if (count >= min_area_) {
            DetectedPoint pt;
            pt.id = 0;
            pt.x = static_cast<float>((sum_x / count) / width);
            pt.y = static_cast<float>((sum_y / count) / height);
            results.push_back(pt);
        }

        return results;
    }

private:
    float min_area_;
};

} // namespace openprojmap
