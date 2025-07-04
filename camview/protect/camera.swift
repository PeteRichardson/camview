//
//  camera.swift
//  camview
//
//  Created by Peter Richardson on 6/30/25.
//

struct Camera: ProtectFetchable {    
    //static let v1APIPath = "cameras"
    static let urlSuffix = "cameras"
    
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
}
