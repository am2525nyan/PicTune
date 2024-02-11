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
        let userdefaults = UserDefaults(suiteName: "group.PIcTune")
     var images: [UIImage] = []
        let imageUrlString = userdefaults!.string(forKey: "first")
        let imageUrl = URL(string: imageUrlString!)
        let imageData = try? Data(contentsOf: imageUrl!)
        let uiImage = UIImage(data: imageData!)
     images.append(uiImage!)
     
     let imageUrlString2 = userdefaults!.string(forKey: "second")
     let imageUrl2 = URL(string: imageUrlString2!)
     let imageData2 = try? Data(contentsOf: imageUrl2!)
     let uiImage2 = UIImage(data: imageData2!)
     images.append(uiImage2!)
     let imageUrlString3 = userdefaults!.string(forKey: "third")
     let imageUrl3 = URL(string: imageUrlString3!)
     let imageData3 = try? Data(contentsOf: imageUrl3!)
     let uiImage3 = UIImage(data: imageData3!)
     images.append(uiImage3!)
        return  images
        
        
        
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




