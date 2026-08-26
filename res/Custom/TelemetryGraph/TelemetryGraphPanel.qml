import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Collapsible Fly View panel plotting any vehicle telemetry value.
///
/// Each chart plots one "source". A source resolves to one fact (vehicle level
/// or a fact group) or to several facts at once (one per ESC, one per battery),
/// in which case the chart draws one line per item.
///
/// Everything is read through the public Fact API — factNames / getFact /
/// getFactGroup — so no QGC internals are relied on beyond that.
Rectangle {
    id:             root
    implicitWidth:  expanded ? _expandedWidth : _collapsedWidth
    implicitHeight: expanded ? _expandedHeight : headerItem.implicitHeight + (_margins * 2)
    radius:         ScreenTools.defaultFontPixelWidth / 2
    color:          qgcPal.window
    opacity:        0.85
    clip:           true
    visible:        _activeVehicle !== null && _activeVehicle !== undefined

    // Set here rather than at the use site so the panel drops into the Fly
    // View column without extra wiring. Ignored when not inside a layout.
    Layout.preferredWidth:  implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight:   implicitHeight
    Layout.fillHeight:      true
    Layout.alignment:       Qt.AlignLeft | Qt.AlignTop

    property bool expanded:         true
    property int  sampleIntervalMs: 200     ///< 5 Hz sampling
    property int  maxCharts:        4
    property int  maxSeries:        8       ///< Cap on lines drawn for an indexed source

    /// One colour per series, readable on both the light and dark QGC themes
    readonly property var seriesColors: [
        "#4CAF50", "#FF9800", "#2196F3", "#E91E63",
        "#9C27B0", "#00BCD4", "#FFC107", "#8BC34A"
    ]

    readonly property var windowChoices: [10, 30, 60, 120]

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Settings {
        id:         panelSettings
        category:   "CustomTelemetryGraph"

        property string sourcesJson:    ""
        property int    windowSecs:     30
        property bool   startExpanded:  true
    }

    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    // Read inside _factsForSource so every binding through it re-evaluates when
    // the vehicle starts reporting ESCs or batteries.
    property int  _escCount:        _activeVehicle && _activeVehicle.escs ? _activeVehicle.escs.count : 0
    property int  _batteryCount:    _activeVehicle && _activeVehicle.batteries ? _activeVehicle.batteries.count : 0
    property real _margins:         ScreenTools.defaultFontPixelWidth * 0.5
    property real _expandedWidth:   ScreenTools.defaultFontPixelWidth * 44
    property real _collapsedWidth:  ScreenTools.defaultFontPixelWidth * 11
    property real _expandedHeight:  ScreenTools.defaultFontPixelHeight * 26
    property real _elapsedSec:      0

    /// Charts, in display order. Persisted as JSON.
    property var _sources: []

    // What the panel shows before the user has configured anything: the ESC
    // telemetry this overlay started life as.
    readonly property var _defaultSources: [
        { kind: "list", model: "escs", fact: "rpm" },
        { kind: "list", model: "escs", fact: "voltage" },
        { kind: "list", model: "escs", fact: "current" }
    ]

    Component.onCompleted: {
        expanded = panelSettings.startExpanded
        let restored = []
        if (panelSettings.sourcesJson !== "") {
            try {
                restored = JSON.parse(panelSettings.sourcesJson)
            } catch (error) {
                console.warn("TelemetryGraphPanel: ignoring unreadable saved sources:", error)
            }
        }
        _sources = (restored && restored.length > 0) ? restored : _defaultSources.slice()
    }

    onExpandedChanged: {
        panelSettings.startExpanded = expanded
        _resetHistory()
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() { root._resetHistory() }
    }

    function _saveSources() {
        panelSettings.sourcesJson = JSON.stringify(_sources)
    }

    function _addSource(source) {
        if (_sources.length >= maxCharts) {
            return
        }
        _sources = _sources.concat([source])
        _saveSources()
        _resetHistory()
    }

    function _replaceSource(index, source) {
        let next = _sources.slice()
        next[index] = source
        _sources = next
        _saveSources()
        _resetHistory()
    }

    function _removeSource(index) {
        let next = _sources.slice()
        next.splice(index, 1)
        _sources = next
        _saveSources()
        _resetHistory()
    }

    function _resetHistory() {
        _elapsedSec = 0
        for (let i = 0; i < chartRepeater.count; i++) {
            const chart = chartRepeater.itemAt(i)
            if (chart) {
                chart.clearData()
            }
        }
    }

    /// Resolve a source to the list of Facts it plots, newest vehicle state each time.
    function _factsForSource(source) {
        const vehicle = _activeVehicle
        if (!vehicle || !source) {
            return []
        }

        if (source.kind === "vehicle") {
            return vehicle.factExists(source.fact) ? [vehicle.getFact(source.fact)] : []
        }

        if (source.kind === "group") {
            const group = vehicle.getFactGroup(source.group)
            return (group && group.factExists(source.fact)) ? [group.getFact(source.fact)] : []
        }

        if (source.kind === "list") {
            const items = source.model === "escs" ? vehicle.escs : vehicle.batteries
            if (!items) {
                return []
            }
            let facts = []
            const reported = source.model === "escs" ? _escCount : _batteryCount
            const count = Math.min(reported, maxSeries)
            for (let i = 0; i < count; i++) {
                const item = items.get(i)
                if (item && item.factExists(source.fact)) {
                    facts.push(item.getFact(source.fact))
                }
            }
            return facts
        }

        return []
    }

    function _sourceLabel(source) {
        const facts = _factsForSource(source)
        if (facts.length > 0 && facts[0].shortDescription !== "") {
            return facts[0].shortDescription
        }
        return source ? source.fact : ""
    }

    function _sourceUnits(source) {
        const facts = _factsForSource(source)
        return facts.length > 0 ? facts[0].units : ""
    }

    function _seriesLabels(source) {
        if (!source || source.kind !== "list") {
            return []
        }
        const prefix = source.model === "escs" ? "M" : "B"
        const facts = _factsForSource(source)
        let labels = []
        for (let i = 0; i < facts.length; i++) {
            labels.push(prefix + (i + 1))
        }
        return labels
    }

    function _sourceDecimals(source) {
        const facts = _factsForSource(source)
        if (facts.length === 0) {
            return 2
        }
        // decimalPlaces can be a sentinel for "unspecified"; keep it sane for a chart
        return Math.max(0, Math.min(facts[0].decimalPlaces, 3))
    }

    function _sample() {
        _elapsedSec += sampleIntervalMs / 1000

        for (let i = 0; i < chartRepeater.count; i++) {
            const chart = chartRepeater.itemAt(i)
            if (!chart) {
                continue
            }
            const facts = _factsForSource(_sources[i])
            let values = []
            for (let j = 0; j < facts.length; j++) {
                values.push(facts[j].value)
            }
            chart.addSample(_elapsedSec, values)
        }
    }

    Timer {
        interval:       root.sampleIntervalMs
        repeat:         true
        // No point burning CPU while collapsed or hidden
        running:        root.visible && root.expanded && root._sources.length > 0
        onTriggered:    root._sample()
    }

    FactSourceDialog {
        id:         sourceDialog
        parent:     Overlay.overlay
        anchors.centerIn: Overlay.overlay
        vehicle:    root._activeVehicle

        /// -1 means "adding a new chart", otherwise the chart being changed
        property int targetIndex: -1

        onSourceAccepted: (source) => {
            if (targetIndex < 0) {
                root._addSource(source)
            } else {
                root._replaceSource(targetIndex, source)
            }
        }
    }

    ColumnLayout {
        anchors.fill:       parent
        anchors.margins:    root._margins
        spacing:            root._margins

        Item {
            id:                     headerItem
            Layout.fillWidth:       true
            Layout.preferredHeight: headerRow.implicitHeight

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
                    text:               qsTr("GRAPH")
                    font.bold:          true
                    color:              qgcPal.text
                    Layout.alignment:   Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Add a chart
                QGCLabel {
                    visible:            root.expanded && root._sources.length < root.maxCharts
                    text:               "+"
                    font.bold:          true
                    color:              qgcPal.buttonHighlight
                    Layout.alignment:   Qt.AlignVCenter

                    MouseArea {
                        anchors.fill:       parent
                        anchors.margins:    -ScreenTools.defaultFontPixelWidth / 2
                        onClicked: {
                            sourceDialog.targetIndex = -1
                            sourceDialog.open()
                        }
                    }
                }

                // Cycles the visible time window
                QGCLabel {
                    visible:            root.expanded
                    text:               qsTr("%1s").arg(panelSettings.windowSecs)
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.buttonHighlight
                    Layout.alignment:   Qt.AlignVCenter

                    MouseArea {
                        anchors.fill:       parent
                        anchors.margins:    -ScreenTools.defaultFontPixelWidth / 2
                        onClicked: {
                            const index = root.windowChoices.indexOf(panelSettings.windowSecs)
                            panelSettings.windowSecs = root.windowChoices[(index + 1) % root.windowChoices.length]
                            root._resetHistory()
                        }
                    }
                }
            }
        }

        QGCLabel {
            visible:            root.expanded && root._sources.length === 0
            Layout.fillWidth:   true
            text:               qsTr("Press + to add a chart")
            font.pointSize:     ScreenTools.smallFontPointSize
            color:              qgcPal.text
        }

        Repeater {
            id:     chartRepeater
            model:  root._sources

            TelemetryChart {
                Layout.fillWidth:   true
                Layout.fillHeight:  true
                visible:            root.expanded
                title:              root._sourceLabel(modelData)
                units:              root._sourceUnits(modelData)
                seriesLabels:       root._seriesLabels(modelData)
                windowSecs:         panelSettings.windowSecs
                seriesColors:       root.seriesColors
                clampToZero:        false
                decimals:           root._sourceDecimals(modelData)

                onTitleClicked: {
                    sourceDialog.targetIndex = index
                    sourceDialog.open()
                }

                onRemoveClicked: root._removeSource(index)
            }
        }
    }
}
