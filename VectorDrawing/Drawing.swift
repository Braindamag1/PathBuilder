//
//  ContentView.swift
//  VectorDrawing
//
//  Created by braindamage on 2023/3/8.
//

import SwiftUI

struct Drawing: View {
    @State var path: Path = .init()
    @GestureState var currentDrag: DragGesture.Value? = nil
    var livePath: Path {
        var copy = path
        if let state = currentDrag {
            copy.update(for: state)
        }
        return copy
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            livePath.stroke(Color.black, lineWidth: 2)
            Points(path: livePath)

        }.gesture(
            // local means entire window
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($currentDrag, body: { value, state, _ in
                    state = value
                })
                .onEnded({ state in
                    path.update(for: state)
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

    mutating func update(for state: DragGesture.Value) {
        if !isEmpty,
           let previous = elements.last {
            var control1: CGPoint?
            switch previous {
            case let .quadCurve(to: to, control: control),
                 let .curve(to: to, control1: _, control2: control):
                control1 = control.mirrored(relativeTo: to)
            default:
                ()
            }
            let isDrag = state.location.distance(to: state.startLocation) > 1
            if isDrag {
                let control = state.location.mirrored(relativeTo: state.startLocation)
                if let c1 = control1 {
                    addCurve(to: state.startLocation, control1: c1, control2: control)
                } else {
                    addQuadCurve(to: state.startLocation, control: control)
                }
            } else {
                if let c1 = control1 {
                    addCurve(to: state.startLocation, control1: c1, control2: state.startLocation)
                } else {
                    addLine(to: state.startLocation)
                }
            }
        } else {
            move(to: state.startLocation)
        }
    }
}

extension Path.Element: Identifiable { // hack for ForEach
    public var id: String { "\(self)" }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = (point.x - x) * (point.x - x)
        let dy = (point.y - y) * (point.y - y)
        return sqrt(dx + dy)
    }

    func mirrored(relativeTo p: CGPoint) -> CGPoint {
        let relative: CGPoint = .init(x: x - p.x, y: y - p.y)
        return .init(x: p.x - relative.x, y: p.y - relative.y)
    }
}

struct PathPoint: View {
    var element: Path.Element
    func pathPoint(at point: CGPoint) -> some View {
        Circle()
            .stroke(Color.black)
            .background(
                Circle()
                    .fill(Color.white)
            )
            .padding(2)
            .frame(width: 14, height: 14)
            .offset(x: point.x - 7, y: point.y - 7)
    }

    func controlPoint(at point: CGPoint) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.black)
            .background(RoundedRectangle(cornerRadius: 2).fill(Color.white))
            .padding(4)
            .frame(width: 14, height: 14)
            .offset(x: point.x - 7, y: point.y - 7)
    }

    var body: some View {
        switch element {
        case let .line(to: point),
             let .move(to: point):
            pathPoint(at: point)
        case let .quadCurve(to: to, control: control),
            let .curve(to: to, control1: _, control2: control):
            let mirrored = control.mirrored(relativeTo: to)
            Path { path in
                path.move(to: control)
                path.addLine(to: to)
                path.addLine(to: mirrored)
            }.stroke(Color.gray)
            pathPoint(at: to)
            controlPoint(at: control)
            controlPoint(at: mirrored)
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
