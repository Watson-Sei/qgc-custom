import QtQuick
import QtQuick.Layouts
import QtGraphs

import QGroundControl
import QGroundControl.Controls

/// A rolling strip chart: one LineSeries per ESC, X is "seconds ago" so the
/// newest sample always sits at 0 on the right hand edge.
///
/// Data is pushed in by the owner via addSample(); the component keeps its own
/// ring buffer and never talks to the vehicle directly.
ColumnLayout {
    id:         root
    spacing:    0

    property string title:          ""
    property string units:          ""
    property real   windowSecs:     30      ///< Visible time span in seconds
    property var    seriesColors:   []
    property bool   clampToZero:    true    ///< Never let the Y axis go below 0
    property int    decimals:       0       ///< Decimals used for the latest-value readout
    property real   minYSpan:       1       ///< Smallest Y range, avoids a jittery axis on flat data

    /// Number of plotted ESCs, and their latest values (NaN when not reporting)
    property int    seriesCount:    0
    property var    latestValues:   []

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // history[i] is an array of { t: seconds, v: value } for ESC i
    property var _history:  []
    property var _series:   []

    Component {
        id: lineSeriesComponent
        LineSeries { }
    }

    /// Append one sample per ESC. values[i] may be NaN/undefined when missing.
    function addSample(tSec, values) {
        _ensureSeries(values.length)

        const cutoff = tSec - windowSecs
        let vMin = Number.POSITIVE_INFINITY
        let vMax = Number.NEGATIVE_INFINITY
        let latest = []

        for (let i = 0; i < _series.length; i++) {
            const history = _history[i]
            const value = i < values.length ? Number(values[i]) : NaN

            if (isFinite(value)) {
                history.push({ t: tSec, v: value })
            }
            while (history.length > 0 && history[0].t < cutoff) {
                history.shift()
            }

            // X is relative to "now" so the axis stays fixed at [-windowSecs, 0]
            let points = []
            for (let j = 0; j < history.length; j++) {
                points.push(Qt.point(history[j].t - tSec, history[j].v))
                vMin = Math.min(vMin, history[j].v)
                vMax = Math.max(vMax, history[j].v)
            }
            _series[i].replace(points)

            latest.push(history.length > 0 ? history[history.length - 1].v : NaN)
        }

        seriesCount = _series.length
        latestValues = latest
        _updateYAxis(vMin, vMax)
    }

    /// Drop all history, e.g. when the active vehicle changes
    function clearData() {
        for (let i = 0; i < _series.length; i++) {
            _history[i] = []
            _series[i].clear()
        }
        latestValues = []
    }

    function _updateYAxis(vMin, vMax) {
        if (!isFinite(vMin) || !isFinite(vMax)) {
            return
        }
        if (clampToZero) {
            vMin = Math.min(0, vMin)
        }
        if (vMax - vMin < minYSpan) {
            const center = (vMax + vMin) / 2
            vMin = center - (minYSpan / 2)
            vMax = center + (minYSpan / 2)
            if (clampToZero) {
                vMin = Math.min(0, vMin)
            }
        }
        const padding = (vMax - vMin) * 0.08
        axisY.min = clampToZero ? Math.min(0, vMin - padding) : vMin - padding
        axisY.max = vMax + padding
    }

    function _ensureSeries(count) {
        while (_series.length < count) {
            const index = _series.length
            const color = seriesColors.length > 0 ? seriesColors[index % seriesColors.length] : qgcPal.text
            const series = lineSeriesComponent.createObject(graphsView, {
                color:  color,
                width:  ScreenTools.isMobile ? 2 : 1.5,
                axisX:  axisX,
                axisY:  axisY
            })
            graphsView.addSeries(series)
            _series.push(series)
            _history.push([])
        }
        while (_series.length > count) {
            const series = _series.pop()
            _history.pop()
            graphsView.removeSeries(series)
            // Deliberately not destroy()ed: QGraphsView keeps an internal pointer
            // that is only cleared on the next updatePolish() pass (see the same
            // note in QGC's MAVLinkChart.qml). It dies with graphsView instead.
        }
    }

    RowLayout {
        Layout.fillWidth:   true
        spacing:            ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text:           root.units === "" ? root.title : root.title + " [" + root.units + "]"
            font.pointSize: ScreenTools.smallFontPointSize
            color:          qgcPal.text
        }

        Item { Layout.fillWidth: true }

        // Latest value of each ESC, colour matched to its line
        Repeater {
            model: root.seriesCount

            QGCLabel {
                property real _value: index < root.latestValues.length ? root.latestValues[index] : NaN

                text:           isFinite(_value) ? _value.toFixed(root.decimals) : "–"
                font.pointSize: ScreenTools.smallFontPointSize
                font.family:    ScreenTools.fixedFontFamily
                color:          root.seriesColors.length > 0 ? root.seriesColors[index % root.seriesColors.length] : qgcPal.text
            }
        }
    }

    GraphsView {
        id:                 graphsView
        Layout.fillWidth:   true
        Layout.fillHeight:  true
        marginTop:          0
        marginBottom:       ScreenTools.defaultFontPixelHeight
        marginLeft:         ScreenTools.defaultFontPixelWidth
        marginRight:        0

        theme: GraphsTheme {
            colorScheme:                qgcPal.globalTheme === QGCPalette.Light ? GraphsTheme.ColorScheme.Light : GraphsTheme.ColorScheme.Dark
            backgroundVisible:          false
            plotAreaBackgroundColor:    "transparent"
            grid.mainColor:             Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.25)
            grid.subColor:              Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.12)
            grid.mainWidth:             1
            labelBackgroundVisible:     false
            labelTextColor:             qgcPal.text
            axisXLabelFont.family:      ScreenTools.fixedFontFamily
            axisXLabelFont.pointSize:   ScreenTools.smallFontPointSize
            axisYLabelFont.family:      ScreenTools.fixedFontFamily
            axisYLabelFont.pointSize:   ScreenTools.smallFontPointSize
        }

        axisX: ValueAxis {
            id:             axisX
            min:            -root.windowSecs
            max:            0
            tickInterval:   root.windowSecs / 3
            subTickCount:   0
        }

        axisY: ValueAxis {
            id:             axisY
            min:            0
            max:            1
            lineVisible:    false
        }
    }
}
