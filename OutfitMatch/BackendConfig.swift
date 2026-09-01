//
//  BackendConfig.swift
//  OutfitMatch
//

import Foundation

enum BackendConfig {
    // Simulator only: this is the Mac's own loopback address, reachable
    // because the Simulator shares the host's network stack. Testing on a
    // real device needs the Mac's LAN IP instead (e.g. http://192.168.x.x:5050)
    // since "localhost" on a physical iPhone means the iPhone itself.
    static let baseURL = URL(string: "http://127.0.0.1:5050")!
}
