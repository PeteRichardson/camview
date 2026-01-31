var target: String {
    #if ALL
    return "All"
    #elseif BACKYARD180
    return "BACKYARD180"
    #elseif DOORANDDRIVEWAY
    return "DoorAndDriveway"
    #elseif DECK
    return "Deck"
    #elseif DRIVEWAY180
    return "Driveway180"
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