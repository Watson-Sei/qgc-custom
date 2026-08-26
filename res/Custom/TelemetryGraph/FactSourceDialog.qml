import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Picker for "which telemetry value should this chart plot".
///
/// A source is one of three shapes, mirroring how QGC exposes telemetry:
///   { kind: "vehicle",              fact: "throttlePct" }  -> one series
///   { kind: "group", group: "gps",  fact: "hdop"        }  -> one series
///   { kind: "list",  model: "escs", fact: "rpm"         }  -> one series per item
Popup {
    id:         root
    modal:      true
    focus:      true
    padding:    ScreenTools.defaultFontPixelWidth
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    /// Emitted with the chosen source object
    signal sourceAccepted(var source)

    property var vehicle: null

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    background: Rectangle {
        color:          qgcPal.window
        border.color:   qgcPal.text
        border.width:   1
        radius:         ScreenTools.defaultFontPixelWidth / 2
    }

    // Indexed models are not part of factGroupNames, so they are listed by hand.
    readonly property var _listModels: [
        { label: qsTr("ESC (per motor)"),     model: "escs" },
        { label: qsTr("Battery (per pack)"),  model: "batteries" }
    ]

    property var _groupNames: vehicle ? vehicle.factGroupNames : []

    // Category list: vehicle-level facts, then each fact group, then indexed models
    property var _categories: {
        let list = [qsTr("Vehicle")]
        for (let i = 0; i < _groupNames.length; i++) {
            list.push(_groupNames[i])
        }
        for (let j = 0; j < _listModels.length; j++) {
            list.push(_listModels[j].label)
        }
        return list
    }

    property int _categoryIndex: 0

    /// Fact names available in the selected category
    property var _factNames: {
        if (!vehicle) {
            return []
        }
        const index = _categoryIndex
        if (index === 0) {
            return vehicle.factNames
        }
        if (index <= _groupNames.length) {
            const group = vehicle.getFactGroup(_groupNames[index - 1])
            return group ? group.factNames : []
        }
        // Indexed model: describe it using its first entry
        const listModel = _modelForIndex(index)
        const items = listModel === "escs" ? vehicle.escs : vehicle.batteries
        return (items && items.count > 0) ? items.get(0).factNames : []
    }

    function _modelForIndex(index) {
        return _listModels[index - 1 - _groupNames.length].model
    }

    function _buildSource(categoryIndex, factName) {
        if (categoryIndex === 0) {
            return { kind: "vehicle", fact: factName }
        }
        if (categoryIndex <= _groupNames.length) {
            return { kind: "group", group: _groupNames[categoryIndex - 1], fact: factName }
        }
        return { kind: "list", model: _modelForIndex(categoryIndex), fact: factName }
    }

    ColumnLayout {
        spacing: ScreenTools.defaultFontPixelHeight / 2

        QGCLabel {
            text:       qsTr("Chart source")
            font.bold:  true
            color:      qgcPal.text
        }

        QGCLabel {
            visible:        !root.vehicle
            text:           qsTr("Connect a vehicle to choose a value")
            font.pointSize: ScreenTools.smallFontPointSize
            color:          qgcPal.text
        }

        GridLayout {
            columns:            2
            columnSpacing:      ScreenTools.defaultFontPixelWidth
            visible:            root.vehicle !== null

            QGCLabel { text: qsTr("Category"); color: qgcPal.text }

            QGCComboBox {
                id:                     categoryCombo
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 28
                model:                  root._categories
                currentIndex:           root._categoryIndex
                onActivated:            (index) => { root._categoryIndex = index }
            }

            QGCLabel { text: qsTr("Value"); color: qgcPal.text }

            QGCComboBox {
                id:                     factCombo
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 28
                model:                  root._factNames
                currentIndex:           0
            }
        }

        RowLayout {
            Layout.alignment:   Qt.AlignRight
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCButton {
                text:       qsTr("Cancel")
                onClicked:  root.close()
            }

            QGCButton {
                text:       qsTr("OK")
                primary:    true
                enabled:    root.vehicle !== null && root._factNames.length > 0
                onClicked: {
                    root.sourceAccepted(root._buildSource(root._categoryIndex,
                                                          root._factNames[factCombo.currentIndex]))
                    root.close()
                }
            }
        }
    }
}
