import ExpoModulesCore
import Darwin

public class NetworkSpeedModule: Module {
  public func definition() -> ModuleDefinition {
    Name("NetworkSpeed")

    Function("getTrafficBytes") { () -> [String: Any] in
      return Self.readTrafficBytes()
    }

    Function("isSupported") { () -> Bool in
      return true
    }
  }

  /// Reads cumulative interface byte counters via getifaddrs (AF_LINK).
  /// Covers Wi‑Fi (en*) and cellular (pdp_ip*) — same approach as iOS system monitors.
  private static func readTrafficBytes() -> [String: Any] {
    var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else {
      return [
        "rxBytes": 0,
        "txBytes": 0,
        "supported": false
      ]
    }
    defer { freeifaddrs(ifaddrPointer) }

    var rxBytes: UInt64 = 0
    var txBytes: UInt64 = 0

    var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddr
    while let addr = pointer {
      let name = String(cString: addr.pointee.ifa_name)
      let family = Int32(addr.pointee.ifa_addr.pointee.sa_family)

      if family == AF_LINK,
         name != "lo0",
         !name.hasPrefix("awdl"),
         !name.hasPrefix("llw"),
         !name.hasPrefix("utun"),
         !name.hasPrefix("ipsec"),
         let data = addr.pointee.ifa_data {
        let networkData = data.assumingMemoryBound(to: if_data.self)
        rxBytes += UInt64(networkData.pointee.ifi_ibytes)
        txBytes += UInt64(networkData.pointee.ifi_obytes)
      }

      pointer = addr.pointee.ifa_next
    }

    return [
      "rxBytes": NSNumber(value: rxBytes),
      "txBytes": NSNumber(value: txBytes),
      "supported": true
    ]
  }
}
