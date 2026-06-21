//
//  questionnareApp.swift
//  questionnare
//
//  Created by yukizumi akiyama on 2026/06/20.
//

import SwiftUI

@main
struct questionnareApp: App {
    @StateObject private var store = SurveyStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
