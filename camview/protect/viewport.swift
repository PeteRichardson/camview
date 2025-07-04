//
//  viewport.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//



struct Viewport: ProtectFetchable {
    //static let v1APIPath = "viewers"
    static let urlSuffix = "viewers"

    var id: String
    var liveview: String
    var name: String
    var state: String
    var streamLimit: Int
    
    static var csvHeader : String = "name,id,liveview,state,streamLimit"

    var description: String {
        "\(name.padded(to:17)) <\(id)> (viewing '\(liveview)')"
    }
    func csvDescription() -> String {
        "\(name),\(id),\(liveview),\(state),\(streamLimit)"
    }
}
