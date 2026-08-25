import QtQuick

import QGroundControl
import QGroundControl.Controls

import Custom.EscTelemetry

// Custom Fly View overlay layer.
//
// This file replaces src/FlyView/FlyViewCustomLayer.qml at runtime through the
// resource override installed by CustomPlugin. It is instantiated by
// FlyView.qml on top of the standard widget layer, so anything added here sits
// above the map/video and below nothing else.
//
// Contract with FlyView.qml (do not rename these properties):
//   parentToolInsets - screen real estate still free below/around the stock widgets
//   totalToolInsets  - what is free once this layer's own additions are accounted for
//   mapControl       - the FlightMap instance
Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

    property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75

    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        // Tell the map how much of the left edge our panel eats so the vehicle
        // is not re-centered underneath it.
        leftEdgeCenterInset:    escTelemetryPanel.visible ? escTelemetryPanel.x + escTelemetryPanel.width + _toolsMargin
                                                          : parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset:    parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset:      parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset:   parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset:   parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset:       parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset:     parentToolInsets.topEdgeCenterInset
        topEdgeRightInset:      parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset:    parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset:   parentToolInsets.bottomEdgeRightInset
    }

    // Positioned on the left edge, directly below the tool strip and above the
    // virtual joystick (if enabled), using the insets handed down to us.
    EscTelemetryPanel {
        id:                     escTelemetryPanel
        anchors.left:           parent.left
        anchors.leftMargin:     _toolsMargin
        anchors.top:            parent.top
        anchors.topMargin:      parentToolInsets.topEdgeLeftInset + _toolsMargin
        availableHeight:        parent.height - anchors.topMargin - parentToolInsets.bottomEdgeLeftInset - _toolsMargin
        visible:                !QGroundControl.videoManager.fullScreen
    }
}
