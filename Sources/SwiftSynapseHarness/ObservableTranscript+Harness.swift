// Generated from CodeGenSpecs/Client-Runtime.md — Do not edit manually. Update spec and re-generate.

import Foundation

#if Core
extension ObservableTranscript {
    /// Restores transcript state from codable entries (session persistence).
    public func restore(from codableEntries: [CodableTranscriptEntry]) {
        restore(entries: codableEntries.map { $0.toTranscriptEntry() })
    }
}
#endif
