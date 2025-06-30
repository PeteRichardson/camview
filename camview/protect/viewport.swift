//
//  viewport.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//



struct Viewport: Decodable, Comparable, CustomCSVConvertible {
    
    var id: String
    var liveview: String
    var modelKey: String
    var name: String
    var state: String
    var streamLimit: Int
    
    static var csvHeader : String = "name,id,liveview,modelKey,state,streamLimit"

    var description: String {
        "\(name.padded(to:17)) <\(id)> (viewing '\(liveview)')"
    }
    func csvDescription() -> String {
        "\(name),\(id),\(liveview),\(modelKey),\(state),\(streamLimit)"
    }
    
    static func < (lhs: Viewport, rhs: Viewport) -> Bool {
        return lhs.name < rhs.name
    }
    static func == (lhs: Viewport, rhs: Viewport) -> Bool {
        lhs.name == rhs.name
    }
    
}
