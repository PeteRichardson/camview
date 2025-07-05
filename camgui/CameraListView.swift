//
//  CameraList.swift
//  camgui
//
//  Created by Peter Richardson on 7/4/25.
//

import SwiftUI

struct CameraList: View {
    @Binding var cameras: [Camera]
    
    var body: some View {
        List {
            ForEach(cameras) { camera in
                VStack(alignment: .leading) {
                    Text(camera.name).font(.headline)
                    Text(camera.id).font(.subheadline).foregroundColor(.secondary)
                }.frame(alignment: .leading)
            }
        }
    }
}

