import Darwin
import Foundation

enum MemoryMetricsReader {
    struct Snapshot: Equatable, Sendable {
        let physicalBytes: Int64
        let usedBytes: Int64
        let swapUsedBytes: Int64
    }

    static func current() -> Snapshot? {
        let physical = Int64(ProcessInfo.processInfo.physicalMemory)
        guard physical > 0 else { return nil }

        guard let vm = readVMStatistics() else { return nil }
        let pageSize = Int64(vm.pageSize)
        let usedPages = Int64(vm.active) + Int64(vm.wire) + Int64(vm.compressor)
        let usedBytes = usedPages * pageSize
        let swapUsed = readSwapUsedBytes() ?? 0

        return Snapshot(
            physicalBytes: physical,
            usedBytes: min(max(usedBytes, 0), physical),
            swapUsedBytes: max(swapUsed, 0)
        )
    }

    private struct VMStatistics {
        let pageSize: vm_size_t
        let active: natural_t
        let wire: natural_t
        let compressor: natural_t
    }

    private static func readVMStatistics() -> VMStatistics? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        guard pageSize > 0 else { return nil }

        return VMStatistics(
            pageSize: pageSize,
            active: stats.active_count,
            wire: stats.wire_count,
            compressor: stats.compressor_page_count
        )
    }

    private static func readSwapUsedBytes() -> Int64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        var mib: [Int32] = [CTL_VM, VM_SWAPUSAGE]
        let result = sysctl(&mib, 2, &usage, &size, nil, 0)
        guard result == 0 else { return nil }
        return Int64(usage.xsu_used)
    }
}
