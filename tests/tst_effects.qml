import QtQuick
import QtQuick.Effects
import QtTest
import "../.config/quickshell/dynamite/effects" as Dynamite

Item {
    id: scene
    width: 200; height: 180
    property color tint: "#9bcac1"
    property real panelHeight: 64
    property bool effectEnabled: true

    Rectangle { anchors.fill: parent; color: "#102030" }
    Item {
        width: 64; height: 64
        layer.enabled: true
        layer.effect: Dynamite.IconTint { color: scene.tint }
        Rectangle { width: 32; height: 32; color: "red" }
        Rectangle { x: 32; width: 32; height: 32; color: "#801188ff" }
        Rectangle { y: 32; width: 32; height: 32; color: "black" }
        Rectangle { x: 32; y: 32; width: 32; height: 32; color: "white" }
    }
    Rectangle {
        id: panelMask
        width: 64; height: scene.panelHeight
        bottomLeftRadius: Math.min(19, height / 2); bottomRightRadius: bottomLeftRadius
        visible: false; layer.enabled: true
    }
    Rectangle {
        x: 80; width: 64; height: scene.panelHeight; color: "#336699"
        layer.enabled: scene.effectEnabled
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            maskEnabled: true; maskSource: panelMask
            maskThresholdMin: 0.5; maskSpreadAtMin: 1
        }
    }
    NumberAnimation { id: resizePanel; target: scene; property: "panelHeight"; from: 64; to: 128; duration: 250 }

    TestCase {
        name: "NativeQt6Effects"
        when: windowShown
        function init() { scene.effectEnabled = true; scene.panelHeight = 64 }
        function test_solidTint_data() {
            return [{tag:"cool", color:"#9bcac1"}, {tag:"warm", color:"#dfb479"}, {tag:"critical", color:"#e18593"}]
        }
        function test_solidTint(data) {
            scene.tint = data.color
            wait(60)
            // Grab the parent: grabbing the source item alone bypasses its layer effect.
            const rendered = grabImage(scene)
            const expected = Qt.color(data.color)
            for (const point of [[16,16],[48,16],[16,48],[48,48]]) {
                const x=point[0], y=point[1]
                const alpha = x>32 && y<32 ? 128/255 : 1
                verify(Math.abs(rendered.red(x,y)-Math.round(expected.r*255*alpha+16*(1-alpha)))<=2)
                verify(Math.abs(rendered.green(x,y)-Math.round(expected.g*255*alpha+32*(1-alpha)))<=2)
                verify(Math.abs(rendered.blue(x,y)-Math.round(expected.b*255*alpha+48*(1-alpha)))<=2)
            }
        }
        function test_maskTracksAnimationAndLayerToggle() {
            wait(60)
            let rendered=grabImage(scene)
            compare(rendered.red(80,0),51) // Square top corner.
            compare(rendered.red(80,63),16) // Rounded bottom corner.
            compare(rendered.red(112,32),51)
            resizePanel.start()
            wait(110)
            verify(scene.panelHeight>64 && scene.panelHeight<128)
            rendered=grabImage(scene)
            compare(rendered.red(112,32),51) // Content remains visible during animation.
            tryCompare(resizePanel,"running",false)
            wait(60)
            rendered=grabImage(scene)
            compare(rendered.red(80,127),16)
            compare(rendered.red(112,126),51)
            scene.effectEnabled=false
            wait(60)
            compare(grabImage(scene).red(80,127),51)
            scene.effectEnabled=true
            wait(60)
            compare(grabImage(scene).red(80,127),16)
        }
    }
}
