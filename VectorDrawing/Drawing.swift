//
//  ContentView.swift
//  VectorDrawing
//
//  Created by braindamage on 2023/3/8.
//

import SwiftUI

struct Drawing: View {
    @State var path: Path = .init()
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            path.stroke(Color.black, lineWidth: 2)
            Points(path: path)
                .background(Color.red)
        }.gesture(
            // local means entire window
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onEnded({ state in
                    if path.isEmpty {
                        path.move(to: state.startLocation)
                    } else {
                        path.addLine(to: state.startLocation)
                    }

                })
        )
    }
}

extension Path {
    var elements: [Element] { // Element is enum
        var results: [Element] = []
        forEach({ results.append($0) })
        return results
    }
}

extension Path.Element: Identifiable { // hack for ForEach
    public var id: String { "\(self)" }
}

struct PathPoint: View {
    var element: Path.Element
    var body: some View {
        switch element {
        case let .line(to: point),
             let .move(to: point):
            Circle()
                .stroke(Color.black)
                .background(
                    Circle()
                        .fill(Color.white)
                )
                .padding(2)
                .frame(width: 14, height: 14)
                .offset(x: point.x - 7, y: point.y - 7)
        default:
            EmptyView()
        }
    }
}

struct Points: View {
    var path: Path
    var body: some View {
        ForEach(path.elements, id: \.id) { element in
            PathPoint(element: element)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Drawing()
            .padding(50)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
