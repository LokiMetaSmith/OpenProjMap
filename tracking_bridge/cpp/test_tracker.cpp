#include "tracker.hpp"
#include <cassert>
#include <cmath>
#include <vector>
#include <iostream>

int main() {
    std::cout << "--- Running test_cpp_bridge ---" << std::endl;

    // Test struct packing size
    assert(sizeof(openprojmap::TouchPacket) == 10);
    std::cout << "✓ TouchPacket size is 10 bytes" << std::endl;

    // Test FastBlobDetector with synthetic 100x100 buffer
    openprojmap::FastBlobDetector detector(5.0f);
    std::vector<uint8_t> buffer(100 * 100, 0);

    // Place a 3x3 bright spot at center (50, 50)
    for (int y = 49; y <= 51; ++y) {
        for (int x = 49; x <= 51; ++x) {
            buffer[y * 100 + x] = 255;
        }
    }

    auto results = detector.processThresholded(buffer.data(), 100, 100);
    assert(results.size() == 1);
    assert(std::abs(results[0].x - 0.5f) < 0.02f);
    assert(std::abs(results[0].y - 0.5f) < 0.02f);
    std::cout << "✓ FastBlobDetector centroid detection passed" << std::endl;

    std::cout << "--- All C++ bridge tests passed! ---" << std::endl;
    return 0;
}
