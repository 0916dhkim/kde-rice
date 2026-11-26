pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: root
    color: "#0b1017"

    // Set by ksplashqml (1 -> 6)
    property int stage: 0
    property real progress: 0.0

    readonly property bool imagesReady: sourceA.status === Image.Ready && sourceB.status === Image.Ready

    function maybeStart(): void {
        if (imagesReady && !rippleAnim.running && root.progress === 0.0) {
            rippleAnim.start();
        }
    }

    onImagesReadyChanged: maybeStart()
    Component.onCompleted: maybeStart()

    // Fallback start in case image loading reports asynchronously
    Timer {
        interval: 80
        running: !rippleAnim.running && root.progress === 0.0
        onTriggered: rippleAnim.start()
    }

    NumberAnimation {
        id: rippleAnim
        target: root
        property: "progress"
        from: 0.0
        to: 1.0
        duration: 1200
        easing.type: Easing.InOutQuad
    }

    // Source A: #11 Icelandic Volcanic Ring Road (exact PreserveAspectCrop)
    Image {
        id: sourceA
        anchors.fill: parent
        source: Qt.resolvedUrl("splash-start.jpg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    // Source B: #15-Edit B Misty Nordic Forest Road + Reindeer (matches desktop wallpaper 1:1)
    Image {
        id: sourceB
        anchors.fill: parent
        source: "file:///usr/share/wallpapers/NordicMist/contents/images/3840x2160.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    // Native Qt 6 GPU liquid-ripple + RGB chromatic aberration reveal shader
    ShaderEffect {
        id: rippleEffect
        anchors.fill: parent
        visible: status === ShaderEffect.Compiled

        property variant texA: sourceA
        property variant texB: sourceB
        property real u_progress: root.progress
        property real u_aspect: root.height > 0 ? (root.width / root.height) : 1.5
        property real u_centerX: 0.68
        property real u_centerY: 0.62
        property real u_sigma: 0.15
        property real u_waveFreq: 5.0
        property real u_pushAmt: 0.145
        property real u_caStrength: 0.02
        property real u_noiseWarp: 1.0

        fragmentShader: Qt.resolvedUrl("shaders/ripple.frag.qsb")
    }

    // Clean crossfade fallback if GPU shader ever fails on software rendering
    Item {
        anchors.fill: parent
        visible: rippleEffect.status !== ShaderEffect.Compiled

        Image {
            anchors.fill: parent
            source: sourceA.source
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }
        Image {
            anchors.fill: parent
            source: sourceB.source
            fillMode: Image.PreserveAspectCrop
            smooth: true
            opacity: root.progress
        }
    }
}
