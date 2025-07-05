//
//  ContentView.swift
//  camgui
//
//  Created by Peter Richardson on 7/4/25.
//

import SwiftUI

struct ContentView: View {
    @State var cameras: [Camera] = []
                                                    
    var body: some View {
        NavigationView {
            CameraList(cameras: $cameras)
        }
        .navigationTitle("Cameras")
        .task {
            let host = UserDefaults.standard.string(forKey: "protect-host") ?? "localhost"
            guard let key = try? Keychain.LoadApiKey() else {
                return
            }
            let protect = ProtectService(host: host, apiKey: key)
            cameras = try! await protect.cameras()
        }
    }
}
