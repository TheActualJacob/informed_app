//
//  InformedWidgetBundle.swift
//  InformedWidget
//
//  Widget bundle entry point for Live Activities
//

import WidgetKit
import SwiftUI

@main
struct InformedWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReelProcessingLiveActivity()
    }
}
