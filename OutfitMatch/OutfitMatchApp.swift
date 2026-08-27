//
//  OutfitMatchApp.swift
//  OutfitMatch
//
//  Created by Selo on 8/27/26.
//

import SwiftUI
import CoreData

@main
struct OutfitMatchApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
