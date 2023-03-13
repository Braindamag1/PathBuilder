//
//  ContentView.swift
//  VectorDrawing
//
//  Created by braindamage on 2023/3/8.
//

import SwiftUI

struct DrawingView: View {
    @State var drawing: Drawing = .init()
    @GestureState var currentDrag: DragGesture.Value? = nil
    var liveDrawing: Drawing {
        var copy = drawing
        if let state = currentDrag {
            copy.update(for: state)
        }
        return copy
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            liveDrawing.path.stroke(Color.black, lineWidth: 2)
            Points(drawing: Binding(get: { liveDrawing }, set: { drawing = $0 }))

        }.gesture(
            // local means entire window
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($currentDrag, body: { value, state, _ in
                    state = value
                })
                .onEnded({ state in
                    drawing.update(for: state)
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
        let isDrag = state.startLocation.distance(to: state.location) > 1

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
    @Binding var element: Drawing.Element
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
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged({ state in
                        element.move(to: state.location)
                    })
            )
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
        if let controlP = element.controlPoints {
            Path { path in
                path.move(to: controlP.0)
                path.addLine(to: element.point)
                path.addLine(to: controlP.1)
            }.stroke(Color.gray)
            controlPoint(at: controlP.0)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged({ state in
                            element.moveControlPoint1(to: state.location)
                        })
                )
            controlPoint(at: controlP.1)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged({ state in
                            element.moveControlPoint2(to: state.location)
                        })
                )
        }
        pathPoint(at: element.point)
    }
}

struct Points: View {
    @Binding var drawing: Drawing
    var body: some View {
        ForEach(Array(zip(drawing.elements, drawing.elements.indices)), id: \.0.id) { element in
            PathPoint(element: $drawing.elements[element.1])
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        DrawingView()
            .padding(50)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Drawing {
    var elements: [Element] = []
    struct Element: Identifiable {
        let id: UUID = .init()
        var point: CGPoint
        var secondaryPoint: CGPoint?
    }
}

extension Drawing.Element {
    var controlPoints: (CGPoint, CGPoint)? {
        guard let secondaryPoint = secondaryPoint else { return nil }
        return (secondaryPoint.mirrored(relativeTo: point), secondaryPoint)
    }

    mutating func move(to: CGPoint) {
        let diff: CGPoint = .init(x: to.x - point.x, y: to.y - point.y)
        point = to
        secondaryPoint = secondaryPoint.map({ .init(x: $0.x + diff.x, y: $0.y + diff.y) })
    }
    
    mutating func moveControlPoint1(to: CGPoint) {
        secondaryPoint = to.mirrored(relativeTo: point)
    }
    
    mutating func moveControlPoint2(to: CGPoint) {
        secondaryPoint = to
    }
}

extension Drawing {
    var path: Path {
        var res = Path()
        guard let first = elements.first else { return res }
        res.move(to: first.point)
        var previousControlPoint: CGPoint?
        for element in elements.dropFirst() {
            if let previousControlPoint = previousControlPoint {
                let mirroed = element.controlPoints?.0 ?? element.point
                res.addCurve(to: element.point, control1: previousControlPoint, control2: mirroed)
            } else {
                if let mirroed = element.controlPoints?.0 {
                    res.addQuadCurve(to: element.point, control: mirroed)
                } else {
                    res.addLine(to: element.point)
                }
            }
            previousControlPoint = element.secondaryPoint
        }
        return res
    }

    mutating func update(for state: DragGesture.Value) {
        let isDrag = state.startLocation.distance(to: state.location) > 1
        elements.append(.init(point: state.startLocation, secondaryPoint: isDrag ? state.location : nil))
    }
}
