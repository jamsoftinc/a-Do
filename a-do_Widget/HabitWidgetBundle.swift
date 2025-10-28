//
//  HabitWidgetBundle.swift
//  a-do_Widget
//
//  Widget Bundle for all widgets
//

import WidgetKit
import SwiftUI

@main
struct ADOWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitWidget()
        ReminderWidget()
        FocusWidget()
        TimeTrackingWidget()
    }
}
