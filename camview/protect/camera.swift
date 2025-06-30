//
//  camera.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

struct Camera: ProtectAPIObject {
    
    static let v1APIPath = "cameras"
    
    var id: String
    var state: String
    var name: String
    var isMicEnabled: Bool
    var micVolume: Int
    var videoMode: String
    var hdrType : String
    
    // NOT IMPLEMENTED YET
    // osdSettings
    // ledSettings
    // lcdMessage
    // featureFlags
    // smartDetectSettings
    // activePatrolSlot
    // modelKey


    static var csvHeader : String = "name,id,state,isMicEnabled,micVolume,videoMode,hdrType"

    var description: String {
        "\(name.padded(to:17)) <\(id)> [\(state)]"
    }
    
    func csvDescription() -> String {
        "\(name),\(id),\(state),\(isMicEnabled),\(micVolume),\(videoMode),\(hdrType)"
    }
    
    static func < (lhs: Camera, rhs: Camera) -> Bool {
        return lhs.name < rhs.name
    }
    static func == (lhs: Camera, rhs: Camera) -> Bool {
        lhs.name == rhs.name
    }
}
