import QtQuick
import QtQuick.Effects

// Flatten the source RGB to white before tinting; retain its alpha and soft edges.
// Colorization alone would preserve luminance, leaving dark icon pixels dark.
MultiEffect {
    property color color: "white"
    autoPaddingEnabled: false
    contrast: -1.0
    brightness: 0.5
    colorization: 1.0
    colorizationColor: color
}
