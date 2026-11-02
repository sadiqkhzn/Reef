import Darwin
import Foundation
import SwiftUI

/// Live CPU, memory, and network telemetry sampled from public mach/BSD APIs.
@MainActor
final class SystemMonitorModel: ObservableObject {
    @Published private(set) var cpu: Double = 0            // 0…1 total load
    @Published private(set) var cpuHistory: [Double] = []  // recent samples
    @Published private(set) var memUsed: Double = 0        // bytes
    @Published private(set) var memTotal: Double = 0       // bytes
    @Published private(set) var netDown: Double = 0        // bytes/sec
    @Published private(set) var netUp: Double = 0          // bytes/sec

    private let historyLength = 40
    private var lastCPUTicks: (used: Double, total: Double)?
    private var lastNet: (down: UInt64, up: UInt64, at: Date)?
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        memTotal = Double(ProcessInfo.processInfo.physicalMemory)
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        cpu = sampleCPU()
        cpuHistory.append(cpu)
        if cpuHistory.count > historyLength { cpuHistory.removeFirst(cpuHistory.count - historyLength) }
        memUsed = sampleMemoryUsed()
        sampleNetwork()
    }

    // MARK: - CPU

    private func sampleCPU() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return cpu }

        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        let used = user + system + nice
        let total = used + idle

        defer { lastCPUTicks = (used, total) }
        guard let last = lastCPUTicks else { return 0 }
        let deltaUsed = used - last.used
        let deltaTotal = total - last.total
        guard deltaTotal > 0 else { return cpu }
        return min(1, max(0, deltaUsed / deltaTotal))
    }

    // MARK: - Memory

    private func sampleMemoryUsed() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return memUsed }
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count)
        let wired = Double(stats.wire_count)
        let compressed = Double(stats.compressor_page_count)
        return (active + wired + compressed) * pageSize
    }

    // MARK: - Network

    private func sampleNetwork() {
        var down: UInt64 = 0
        var up: UInt64 = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let addr = pointer {
            let name = String(cString: addr.pointee.ifa_name)
            if (name.hasPrefix("en") || name.hasPrefix("pdp_ip")),
                addr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                let data = addr.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self)
                down &+= UInt64(networkData.pointee.ifi_ibytes)
                up &+= UInt64(networkData.pointee.ifi_obytes)
            }
            pointer = addr.pointee.ifa_next
        }

        let now = Date()
        defer { lastNet = (down, up, now) }
        guard let last = lastNet else { return }
        let dt = now.timeIntervalSince(last.at)
        guard dt > 0 else { return }
        netDown = max(0, Double(down &- last.down) / dt)
        netUp = max(0, Double(up &- last.up) / dt)
    }

    static func formatBytes(_ bytes: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    static func formatRate(_ bytesPerSec: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSec), countStyle: .file) + "/s"
    }
}
