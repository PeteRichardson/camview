//
//  liveview.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

import Foundation

struct Slot: Decodable {
    var cameras: [String]
    var cycleMode: String
    var cycleInterval: Int
}

struct Liveview: ProtectFetchable {
    
    //static let v1APIPath = "liveviews"
    static let urlSuffix = "liveviews"
    
    var id: String
    var name: String
    var isDefault: Bool
    var isGlobal: Bool
    var owner: String
    var layout: Int
    var slots: [Slot]

    static var csvHeader : String = "name,id,isDefault,isGlobal,owner,layout"

    var description: String {
        "\(name.padded(to:17)) <\(id)> \(isDefault ? "(default)" : "")"
    }
    
    func csvDescription() -> String {
        "\(name),\(id),\(isDefault),\(isGlobal),\(owner),\(layout)"
    }
}


