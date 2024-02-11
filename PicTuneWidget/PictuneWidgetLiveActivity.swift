//
//  PictuneWidgetLiveActivity.swift
//  PictuneWidget
//
//  Created by saki on 2024/02/11.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PictuneWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PictuneWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PictuneWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PictuneWidgetAttributes {
    fileprivate static var preview: PictuneWidgetAttributes {
        PictuneWidgetAttributes(name: "World")
    }
}

extension PictuneWidgetAttributes.ContentState {
    fileprivate static var smiley: PictuneWidgetAttributes.ContentState {
        PictuneWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PictuneWidgetAttributes.ContentState {
         PictuneWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PictuneWidgetAttributes.preview) {
   PictuneWidgetLiveActivity()
} contentStates: {
    PictuneWidgetAttributes.ContentState.smiley
    PictuneWidgetAttributes.ContentState.starEyes
}
