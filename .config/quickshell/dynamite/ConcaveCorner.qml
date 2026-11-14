import QtQuick
import QtQuick.Shapes

Shape {
    id: corner
    property real curveRadius: 12
    property color fill: App.palette.bg
    property bool mirrored: false
    property bool inverted: false
    width: curveRadius; height: curveRadius
    preferredRendererType: Shape.CurveRenderer
    transform: Scale { origin.x: corner.width / 2; origin.y: corner.height / 2; xScale: corner.mirrored ? -1 : 1; yScale: corner.inverted ? -1 : 1 }
    ShapePath {
        strokeWidth: -1; fillColor: corner.fill
        startX: 0; startY: 0
        PathLine { x: corner.curveRadius; y: 0 }
        PathLine { x: corner.curveRadius; y: corner.curveRadius }
        PathArc { x: 0; y: 0; radiusX: corner.curveRadius; radiusY: corner.curveRadius; direction: PathArc.Counterclockwise }
    }
}
