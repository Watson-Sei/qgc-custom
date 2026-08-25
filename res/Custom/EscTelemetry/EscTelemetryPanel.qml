import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Collapsible Fly View panel plotting per-ESC RPM, voltage and current.
///
/// Data comes from Vehicle::escs (EscStatusFactGroupListModel), which QGC fills
/// from the standard MAVLink ESC_STATUS / ESC_INFO messages. Nothing here
/// depends on QGC internals beyond those public QML properties, so upstream
/// refactors of the Fly View cannot break it.
Rectangle {
    id:             root
    implicitWidth:  expanded ? _expandedWidth : _collapsedWidth
    implicitHeight: expanded ? _expandedHeight : headerItem.implicitHeight + (_margins * 2)

    // Set here rather than at the use site so the panel drops into the Fly
    // View column (or any other layout) without extra wiring. Ignored when the
    // panel is not inside a layout.
    Layout.preferredWidth:  implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight:   implicitHeight
    Layout.fillHeight:      true
    Layout.alignment:       Qt.AlignLeft | Qt.AlignTop
    radius:     ScreenTools.defaultFontPixelWidth / 2
    clip:       true
    color:      qgcPal.window
    opacity:    0.85
    // No ESC telemetry on this vehicle means the panel stays completely out of the way
    visible:    escCount > 0

    property bool expanded:         true
    property int  sampleIntervalMs: 200     ///< 5 Hz sampling
    property int  windowSecs:       30      ///< Visible history in seconds
    property int  maxEscCount:      8       ///< Upper bound on plotted ESCs

    /// One colour per ESC, readable on both the light and dark QGC themes
    readonly property var seriesColors: [
        "#4CAF50", "#FF9800", "#2196F3", "#E91E63",
        "#9C27B0", "#00BCD4", "#FFC107", "#8BC34A"
    ]

    readonly property var windowChoices: [10, 30, 60, 120]

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property var  _escs:            _activeVehicle ? _activeVehicle.escs : null

    // QGC creates fact groups in blocks of four, because one ESC_STATUS message
    // carries indices index..index+3. A six-motor vehicle therefore reports
    // escs.count == 8, with the last two stuck at zero. ESC_INFO's `count` is
    // the real number of ESCs, so prefer it whenever the vehicle sends it.
    property int  _reportedEscCount: _escs && _escs.count > 0 ? _escs.get(0).count.rawValue : 0
    property int  escCount:        !_escs ? 0
                                    : Math.min(_reportedEscCount > 0 ? _reportedEscCount : _escs.count,
                                               maxEscCount)
    property real _margins:         ScreenTools.defaultFontPixelWidth * 0.5
    property real _expandedWidth:   ScreenTools.defaultFontPixelWidth * 44
    property real _collapsedWidth:  ScreenTools.defaultFontPixelWidth * 9
    property real _expandedHeight:  ScreenTools.defaultFontPixelHeight * 26
    property real _elapsedSec:      0

    onExpandedChanged:   _resetHistory()
    onWindowSecsChanged: _resetHistory()
    onEscCountChanged:   _resetHistory()

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() { root._resetHistory() }
    }

    function _resetHistory() {
        _elapsedSec = 0
        rpmChart.clearData()
        voltageChart.clearData()
        currentChart.clearData()
    }

    function _sample() {
        if (!_escs) {
            return
        }

        const count = escCount
        let rpm = []
        let voltage = []
        let current = []
        for (let i = 0; i < count; i++) {
            const esc = _escs.get(i)
            rpm.push(esc.rpm.rawValue)
            voltage.push(esc.voltage.rawValue)
            current.push(esc.current.rawValue)
        }

        _elapsedSec += sampleIntervalMs / 1000
        rpmChart.addSample(_elapsedSec, rpm)
        voltageChart.addSample(_elapsedSec, voltage)
        currentChart.addSample(_elapsedSec, current)
    }

    Timer {
        interval:       root.sampleIntervalMs
        repeat:         true
        // No point burning CPU while collapsed, hidden, or with nothing reporting
        running:        root.visible && root.expanded
        onTriggered:    root._sample()
    }

    ColumnLayout {
        anchors.fill:       parent
        anchors.margins:    root._margins
        spacing:            root._margins

        Item {
            id:                     headerItem
            Layout.fillWidth:       true
            Layout.preferredHeight: headerRow.implicitHeight

            // Declared first so the controls inside headerRow win the clicks
            MouseArea {
                anchors.fill:   parent
                onClicked:      root.expanded = !root.expanded
            }

            RowLayout {
                id:             headerRow
                anchors.fill:   parent
                spacing:        ScreenTools.defaultFontPixelWidth / 2

                QGCLabel {
                    text:               root.expanded ? "▾" : "▸"
                    color:              qgcPal.text
                    Layout.alignment:   Qt.AlignVCenter
                }

                QGCLabel {
                    text:               qsTr("ESC")
                    font.bold:          true
                    color:              qgcPal.text
                    Layout.alignment:   Qt.AlignVCenter
                }

                QGCLabel {
                    visible:            root.expanded
                    text:               qsTr("%1 motors").arg(root.escCount)
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.text
                    Layout.alignment:   Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Cycles the visible time window
                QGCLabel {
                    visible:            root.expanded
                    text:               qsTr("%1s").arg(root.windowSecs)
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.buttonHighlight
                    Layout.alignment:   Qt.AlignVCenter

                    MouseArea {
                        anchors.fill:       parent
                        anchors.margins:    -ScreenTools.defaultFontPixelWidth / 2
                        onClicked: {
                            const index = root.windowChoices.indexOf(root.windowSecs)
                            root.windowSecs = root.windowChoices[(index + 1) % root.windowChoices.length]
                        }
                    }
                }
            }
        }

        // Legend: motor number in the colour of its line
        RowLayout {
            Layout.fillWidth:   true
            visible:            root.expanded
            spacing:            ScreenTools.defaultFontPixelWidth

            Repeater {
                model: root.escCount

                QGCLabel {
                    text:           qsTr("M%1").arg(index + 1)
                    font.pointSize: ScreenTools.smallFontPointSize
                    font.bold:      true
                    color:          root.seriesColors[index % root.seriesColors.length]
                }
            }

            Item { Layout.fillWidth: true }
        }

        EscTelemetryChart {
            id:                 rpmChart
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            visible:            root.expanded
            title:              qsTr("RPM")
            windowSecs:         root.windowSecs
            seriesColors:       root.seriesColors
            clampToZero:        false
            decimals:           0
            minYSpan:           100
        }

        EscTelemetryChart {
            id:                 voltageChart
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            visible:            root.expanded
            title:              qsTr("Voltage")
            units:              qsTr("V")
            windowSecs:         root.windowSecs
            seriesColors:       root.seriesColors
            clampToZero:        false
            decimals:           2
            minYSpan:           0.5
        }

        EscTelemetryChart {
            id:                 currentChart
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            visible:            root.expanded
            title:              qsTr("Current")
            units:              qsTr("A")
            windowSecs:         root.windowSecs
            seriesColors:       root.seriesColors
            decimals:           2
            minYSpan:           1
        }
    }
}
