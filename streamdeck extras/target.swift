var target: String {
    #if ALL
    return "All"
    #elseif DOORANDDRIVEWAY
    return "DoorAndDriveway"
    #elseif DRIVEWAY
    return "Driveway"
    #elseif DRIVEWAY2
    return "Driveway2"
    #elseif FAMILYROOM
    return "FamilyRoom"
    #elseif FIREPIT
    return "Firepit"
    #elseif FRONTDOOR
    return "FrontDoor"
    #elseif GARBAGE
    return "Garbage"
    #elseif KATSALLEY
    return "KatsAlley"
    #elseif SIDEYARD
    return "SideYard"
    #elseif SUMMARY
    return "Summary"
    #else
    return "DEFAULT"
    #endif
}