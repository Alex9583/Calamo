// Peak process memory as the e2e validation measured it: phys_footprint via
// proc_pid_rusage — RSS would count re-ejectable mmapped GGUF pages.
import Darwin

struct MemoryFootprint {
    let footprintMB: Double
    let lifetimePeakMB: Double

    static func sample() -> MemoryFootprint? {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        guard ok == 0 else { return nil }
        return MemoryFootprint(
            footprintMB: Double(info.ri_phys_footprint) / 1_048_576,
            lifetimePeakMB: Double(info.ri_lifetime_max_phys_footprint) / 1_048_576)
    }
}
