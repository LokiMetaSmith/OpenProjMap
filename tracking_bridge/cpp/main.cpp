#include "tracker.hpp"
#include <iostream>
#include <chrono>
#include <thread>

int main(int argc, char** argv) {
    std::string ip = "127.0.0.1";
    int port = 9000;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--ip" && i + 1 < argc) ip = argv[++i];
        else if (arg == "--port" && i + 1 < argc) port = std::stoi(argv[++i]);
    }

    std::cout << "[OpenProjMap C++ Bridge] Starting UDP low-latency transmitter to "
              << ip << ":" << port << "..." << std::endl;

    openprojmap::UDPEmitter emitter(ip, port);
    openprojmap::FastBlobDetector detector;

    std::cout << "[OpenProjMap C++ Bridge] Ready." << std::endl;
    return 0;
}
