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
        let entry = SimpleEntry(date: Date(), images: loadImage())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
            // タイムラインの更新間隔を指定
            let refreshTime = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [SimpleEntry(date: refreshTime, images: loadImage())], policy: .after(refreshTime))
            completion(timeline)
        }
    
    // UserDefaultsから画像のURLを取得し、UIImageに変換するメソッド
    func loadImage() -> [UIImage] {
        guard let defaults = UserDefaults(suiteName: "group.PIcTune"),
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.PIcTune") else { return [] }
        return ["first", "second", "third"].compactMap { key in
            let file = directory.appendingPathComponent("widget-\(key).jpg")
            guard defaults.string(forKey: key) == file.path else { return nil }
            return UIImage(contentsOfFile: file.path)
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
            ForEach(entry.images, id: \.self) { image in
                Image(uiImage: image)
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




