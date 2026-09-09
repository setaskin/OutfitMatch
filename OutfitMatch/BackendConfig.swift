//
//  BackendConfig.swift
//  OutfitMatch
//

import Foundation

enum BackendConfig {
    // Points at the backend deployed on Render (see render.yaml), so the
    // app works from the Simulator, a real device, or anywhere else without
    // needing the Mac's local server running. Render's free tier spins down
    // after 15 minutes idle, so the first request after a quiet spell can
    // take 30-60 seconds.
    //
    // For local backend development (faster iteration, no cold starts),
    // swap this for "http://127.0.0.1:5050" in the Simulator, or the Mac's
    // LAN IP (e.g. "http://192.168.x.x:5050") on a real device — "localhost"
    // on a physical iPhone means the iPhone itself, not the Mac.
    static let baseURL = URL(string: "https://outfitmatch-backend.onrender.com")!
}
