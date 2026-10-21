import Foundation

/// Tiny file logger for debugging in the simulator (visible via
/// `simctl get_app_container <device> <bundle-id> data` + tmp/jmc.log).
func jmcLog(_ message: String) {
    #if DEBUG
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("jmc.log")
    let data = (message + "\n").data(using: .utf8) ?? Data()
    if FileManager.default.fileExists(atPath: url.path),
       let fh = try? FileHandle(forWritingTo: url) {
        defer { try? fh.close() }
        _ = try? fh.seekToEnd()
        _ = try? fh.write(contentsOf: data)
    } else {
        try? data.write(to: url)
    }
    #endif
}
