import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

import Custom.EscTelemetry

// Custom Fly View overlay layer.
//
// This file replaces src/FlyView/FlyViewCustomLayer.qml at runtime through the
// resource override installed by CustomPlugin. It is instantiated by
// FlyView.qml on top of the standard widget layer, so anything added here sits
// above the map/video.
//
// Contract with FlyView.qml (do not rename these properties):
//   parentToolInsets - screen real estate still free around the stock widgets
//   totalToolInsets  - what is free once this layer's own additions are counted
//   mapControl       - the FlightMap instance
//
// To add a panel: drop it into leftEdgeColumn below. Panels are expected to
// set their own Layout attached properties (see EscTelemetryPanel), so the
// column shares the available height between them automatically.
Item {
    id: _root

    property var parentToolInsets
    property var totalToolInsets:   _toolInsets
    property var mapControl

    property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75

    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeTopInset:       parentToolInsets.leftEdgeTopInset
        // Tell the map how much of the left edge our panels eat, so the vehicle
        // is not re-centered underneath them.
        leftEdgeCenterInset:    leftEdgeColumn.occupiedWidth > 0
                                    ? leftEdgeColumn.x + leftEdgeColumn.occupiedWidth + _toolsMargin
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

    // Left edge, below the tool strip and above the virtual joystick.
    ColumnLayout {
        id:                     leftEdgeColumn
        anchors.left:           parent.left
        anchors.leftMargin:     _toolsMargin
        anchors.top:            parent.top
        anchors.topMargin:      parentToolInsets.topEdgeLeftInset + _toolsMargin
        height:                 parent.height - anchors.topMargin - parentToolInsets.bottomEdgeLeftInset - _toolsMargin
        spacing:                _toolsMargin
        visible:                !QGroundControl.videoManager.fullScreen

        // Width actually taken on screen, 0 when every panel is hidden
        property real occupiedWidth: visible ? childrenRect.width : 0

        EscTelemetryPanel { }

        // Add further Fly View panels here.

        // Soaks up the leftover height so the panels stay pinned to the top
        Item { Layout.fillHeight: true }
    }
}
