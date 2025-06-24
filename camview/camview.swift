//
//  main.swift
//  camview
//
//  Created by Peter Richardson on 6/24/25.
//

import Foundation
import Logging
import ArgumentParser




struct CamViewApp : ParsableCommand {
    @Argument(help: "Name of multi-view to switch to")
    var view: String
    
    mutating func run() throws {
        print("You want me to switch to \(view)")
    }
}

@main
struct MainApp {
    static func main() {
        CamViewApp.main()
    }
}
