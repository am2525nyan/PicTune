//
//  PictuneWidget.swift
//  PictuneWidget
//
//  Created by saki on 2024/02/11.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), images:[])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Task {
            let images = await WidgetPhotoLoader.loadImages()
            completion(SimpleEntry(date: Date(), images: images))
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let images = await WidgetPhotoLoader.loadImages()
            let now = Date()
            let refreshTime = now.addingTimeInterval(15 * 60)
            let timeline = Timeline(entries: [SimpleEntry(date: now, images: images)], policy: .after(refreshTime))
            completion(timeline)
        }
    }
}
struct SimpleEntry: TimelineEntry {
    let date: Date
    
    let images: [UIImage]
}

struct PictuneWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(entry.images.indices, id: \.self) { index in
                Image(uiImage: entry.images[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            }
        }
        .widgetBackground(Color(red:0.89, green:  0.749, blue: 0.98))
    
}
                          }

struct PictuneWidget: Widget {
    let kind: String = "PictuneWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PictuneWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PictuneWidget")
        .description("This is an example widget.")
    }
}
extension View {
    // ウィジェットのbackgroundを設定する
    @ViewBuilder
    func widgetBackground(_ style: some ShapeStyle) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                ContainerRelativeShape().foregroundStyle(AnyShapeStyle(style))
            }
        } else {
            self.background(AnyShapeStyle(style))
        }
    }
}



