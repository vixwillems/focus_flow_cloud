import SwiftUI
import WidgetKit

@main
struct FocusFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusFlowLiveActivity()
        FocusFlowStandByWidget()
    }
}
