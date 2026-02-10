//
//  ContentView.swift
//  camgui
//
//  Created by Peter Richardson on 7/4/25.
//

import SwiftUI
import Protect

struct ContentView: View {
    @State var cameras: [Camera] = []
                                                    
    var body: some View {
        NavigationView {
            CameraList(cameras: $cameras)
        }
        .navigationTitle("Cameras")
        .task {
            if let config = Configuration()  {
                let protect = ProtectService(host: config.host, apiKey: config.apiKey)
                cameras = try! await protect.cameras()
            }
        }
    }
}
