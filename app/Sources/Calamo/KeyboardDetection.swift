import IOKit.hid

/// IOHID enumeration only — the manager is never opened, so macOS never
/// prompts for Input Monitoring. Apple keyboards, built-in included, carry
/// an Apple vendor ID; anything else is an external non-Apple one.
enum KeyboardDetection {
    private static let appleVendorIDs: Set<Int> = [0x05AC, 0x004C]

    static func hasNonAppleExternalKeyboard() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let keyboards = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, keyboards as CFDictionary)
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        return devices.contains { device in
            guard let vendor = vendorID(of: device) else { return false }
            return !appleVendorIDs.contains(vendor)
        }
    }

    private static func vendorID(of device: IOHIDDevice) -> Int? {
        IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int
    }
}
