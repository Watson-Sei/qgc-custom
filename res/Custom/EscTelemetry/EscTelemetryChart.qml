import QtQuick
import QtQuick.Layouts
import QtGraphs

import QGroundControl
import QGroundControl.Controls

/// A rolling strip chart: one LineSeries per ESC.
///
/// X is absolute elapsed seconds and the axis window slides with it, so a
/// sample costs one append plus one removal of the expired head rather than a
/// rebuild of every point. The axis labels are rendered relative to the newest
/// sample, so the reader still sees "-30s … 0s".
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

    // Parallel history per ESC: { t: [seconds], v: [values] }. Kept alongside the
    // series so the Y-range scan runs in JS instead of crossing into C++ per point.
    property var  _history:     []
    property var  _series:      []
    property real _latestT:     0
    property int  _tickCount:   0

    // A full min/max scan every tick is wasted work; 1 Hz tracks the data fine.
    readonly property int _yRescanEveryNTicks: 5

    Component {
        id: lineSeriesComponent
        LineSeries { }
    }

    /// Append one sample per ESC. values[i] may be NaN/undefined when missing.
    function addSample(tSec, values) {
        _ensureSeries(values.length)

        _latestT = tSec
        const cutoff = tSec - windowSecs
        let latest = []

        for (let i = 0; i < _series.length; i++) {
            const series = _series[i]
            const history = _history[i]
            const value = i < values.length ? Number(values[i]) : NaN

            if (isFinite(value)) {
                history.t.push(tSec)
                history.v.push(value)
                series.append(tSec, value)
            }

            let expired = 0
            while (expired < history.t.length && history.t[expired] < cutoff) {
                expired++
            }
            if (expired > 0) {
                history.t.splice(0, expired)
                history.v.splice(0, expired)
                series.removeMultiple(0, expired)
            }

            latest.push(history.v.length > 0 ? history.v[history.v.length - 1] : NaN)
        }

        seriesCount = _series.length
        latestValues = latest

        axisX.min = tSec - windowSecs
        axisX.max = tSec

        _tickCount++
        if (_tickCount === 1 || (_tickCount % _yRescanEveryNTicks) === 0) {
            _updateYAxis()
        }
    }

    /// Drop all history, e.g. when the active vehicle or the ESC count changes
    function clearData() {
        for (let i = 0; i < _series.length; i++) {
            _history[i] = { t: [], v: [] }
            _series[i].clear()
        }
        latestValues = []
        _tickCount = 0
    }

    function _updateYAxis() {
        let vMin = Number.POSITIVE_INFINITY
        let vMax = Number.NEGATIVE_INFINITY

        for (let i = 0; i < _history.length; i++) {
            const v = _history[i].v
            for (let j = 0; j < v.length; j++) {
                if (v[j] < vMin) vMin = v[j]
                if (v[j] > vMax) vMax = v[j]
            }
        }

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
            _history.push({ t: [], v: [] })
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
        Layout.fillWidth:       true
        // Without this the row's implicit width becomes a hard floor and the
        // whole panel is pushed wider than its background rectangle.
        Layout.minimumWidth:    0
        spacing:                ScreenTools.defaultFontPixelWidth / 2

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
        Layout.fillWidth:       true
        Layout.fillHeight:      true
        Layout.minimumWidth:    0
        Layout.minimumHeight:   0
        marginTop:              0
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

            // X carries absolute elapsed seconds; show it relative to the newest sample
            labelDelegate: Component {
                Item {
                    property string text

                    implicitWidth:  label.implicitWidth
                    implicitHeight: label.implicitHeight

                    Text {
                        id: label
                        text: {
                            const seconds = parseFloat(parent.text)
                            return isNaN(seconds) ? parent.text : Math.round(seconds - root._latestT) + "s"
                        }
                        color:          qgcPal.text
                        font.family:    ScreenTools.fixedFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }
        }

        axisY: ValueAxis {
            id:             axisY
            min:            0
            max:            1
            tickInterval:   Math.max((max - min) / 4, Number.MIN_VALUE)
            subTickCount:   0
            lineVisible:    false
        }
    }
}
