import Foundation
import MachO

/// The executable's Mach-O UUID — changes with every rebuild, stable
/// across relaunches: the identity the ANE cache is keyed to.
enum BinaryIdentity {
    static func current() -> String? {
        for index in 0..<_dyld_image_count() {
            guard let header = _dyld_get_image_header(index),
                header.pointee.filetype == UInt32(MH_EXECUTE)
            else { continue }
            return uuid(in: header)
        }
        return nil
    }

    private static func uuid(in header: UnsafePointer<mach_header>) -> String? {
        guard header.pointee.magic == MH_MAGIC_64 else { return nil }
        var cursor = UnsafeRawPointer(header) + MemoryLayout<mach_header_64>.size
        for _ in 0..<header.pointee.ncmds {
            let command = cursor.load(as: load_command.self)
            if command.cmd == UInt32(LC_UUID) {
                return UUID(uuid: cursor.load(as: uuid_command.self).uuid).uuidString
            }
            cursor += Int(command.cmdsize)
        }
        return nil
    }
}
