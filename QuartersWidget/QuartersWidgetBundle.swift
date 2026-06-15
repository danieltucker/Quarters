import WidgetKit
import SwiftUI

// Entry point for the widget extension. For now it hosts only the focus-session
// Live Activity (Dynamic Island + lock screen). Add home-screen widgets here later.
@main
struct QuartersWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuartersLiveActivity()
    }
}
