//
//  liveview.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//



struct Slot: Decodable {
    var cameras: [String]
    var cycleMode: String
    var cycleInterval: Int
}

struct Liveview: ProtectAPIObject {
    
    static let v1APIPath = "liveviews"
    
    var id: String
    var modelKey: String
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
    
    static func < (lhs: Liveview, rhs: Liveview) -> Bool {
        return lhs.name < rhs.name
    }
    static func == (lhs: Liveview, rhs: Liveview) -> Bool {
        lhs.name == rhs.name
    }
}
