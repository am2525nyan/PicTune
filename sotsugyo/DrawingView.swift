
import SwiftUI

struct DrawingContentView: View {
    @State private var drawing = Drawing()
    
    var body: some View {
        VStack {
            DrawingView(drawing: $drawing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0))
                .border(Color.black)
        }
    }
}

struct DrawingPath {
    var path = Path()
    let color: Color
    let lineWidth: CGFloat
}

struct Drawing {
    private(set) var paths: [DrawingPath] = []
    
    mutating func addPath(_ path: DrawingPath) {
        paths.append(path)
    }
}

struct DrawingView: View {
    @Binding var drawing: Drawing
    @State private var currentPath: DrawingPath?
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for drawingPath in drawing.paths {
                    context.stroke(drawingPath.path, with: .color(drawingPath.color), lineWidth: drawingPath.lineWidth)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if currentPath == nil {
                            currentPath = DrawingPath(color: .black, lineWidth: 5)
                        }
                        currentPath?.path.addLine(to: value.location)
                    }
                    .onEnded { value in
                        if let currentPath = currentPath {
                            drawing.addPath(currentPath)
                            self.currentPath = nil
                        }
                    }
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        DrawingContentView()
    }
}
