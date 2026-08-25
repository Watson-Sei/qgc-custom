import QtCore
import QtQuick
import QtQuick.Layouts
import QtMultimedia

import QGroundControl
import QGroundControl.Controls

/// Collapsible Fly View panel showing a UVC capture device, with recording.
///
/// Intended for FPV goggles with an HDMI output fed into a USB HDMI capture
/// dongle: macOS exposes such a dongle as an ordinary video input, so nothing
/// here is specific to a particular goggle.
///
/// This is deliberately independent of QGroundControl.videoManager — picking a
/// device here does not disturb the vehicle video configured in Application
/// Settings, and both can be shown at once.
Rectangle {
    id:             root
    implicitWidth:  expanded ? _expandedWidth : _collapsedWidth
    implicitHeight: contentColumn.implicitHeight + (_margins * 2)
    radius:         ScreenTools.defaultFontPixelWidth / 2
    color:          qgcPal.window
    opacity:        0.85
    clip:           true

    // Set here rather than at the use site so the panel drops into a Fly View
    // column without extra wiring. Ignored when not inside a layout.
    Layout.preferredWidth:  implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight:   implicitHeight
    Layout.alignment:       Qt.AlignRight | Qt.AlignTop

    property bool expanded:     true
    property real aspectRatio:  16 / 9

    readonly property bool recording: recorder.recorderState === MediaRecorder.RecordingState

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Settings {
        id:         panelSettings
        category:   "CustomHdmiVideo"

        // Devices are matched by description because device ids are not stable
        // across reboots or ports. Same approach QGC uses for its UVC source.
        property string deviceDescription: ""
        property bool   startExpanded:     true
    }

    property real _margins:         ScreenTools.defaultFontPixelWidth * 0.5
    property real _expandedWidth:   ScreenTools.defaultFontPixelWidth * 40
    property real _collapsedWidth:  ScreenTools.defaultFontPixelWidth * 13
    property real _videoWidth:      _expandedWidth - (_margins * 2)
    property real _videoHeight:     _videoWidth / aspectRatio

    property var  _devices:         mediaDevices.videoInputs
    property var  _selectedDevice: {
        const devices = mediaDevices.videoInputs
        if (devices.length === 0) {
            return null
        }
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].description === panelSettings.deviceDescription) {
                return devices[i]
            }
        }
        return devices[0]
    }

    property string _statusText: ""

    Component.onCompleted: expanded = panelSettings.startExpanded
    onExpandedChanged:     panelSettings.startExpanded = expanded

    function _twoDigits(value) {
        return value.toString().padStart(2, "0")
    }

    function _elapsedString(ms) {
        const total = Math.floor(ms / 1000)
        return _twoDigits(Math.floor(total / 60)) + ":" + _twoDigits(total % 60)
    }

    function _toggleRecording() {
        if (recording) {
            recorder.stop()
            return
        }
        if (!_selectedDevice) {
            return
        }

        const now = new Date()
        const stamp = now.getFullYear() +
                      _twoDigits(now.getMonth() + 1) +
                      _twoDigits(now.getDate()) + "-" +
                      _twoDigits(now.getHours()) +
                      _twoDigits(now.getMinutes()) +
                      _twoDigits(now.getSeconds())
        // writableLocation returns a file: url, so this stays a url throughout
        recorder.outputLocation = StandardPaths.writableLocation(StandardPaths.MoviesLocation) +
                                  "/QGC-HDMI-" + stamp + ".mp4"
        recorder.record()
    }

    MediaDevices { id: mediaDevices }

    CaptureSession {
        videoOutput: videoOutput

        camera: Camera {
            cameraDevice: root._selectedDevice ? root._selectedDevice : mediaDevices.defaultVideoInput
            // Release the capture device when the panel is not showing it, but
            // never pull it out from under an in-progress recording.
            active:       root._selectedDevice !== null &&
                          (root.recording || (root.visible && root.expanded))
        }

        // No AudioInput is attached on purpose: video only, and no microphone
        // permission prompt.
        recorder: MediaRecorder {
            id:         recorder
            quality:    MediaRecorder.HighQuality

            mediaFormat {
                fileFormat: MediaFormat.MPEG4
                videoCodec: MediaFormat.VideoCodec.H264
            }

            onRecorderStateChanged: {
                if (recorderState === MediaRecorder.StoppedState && actualLocation.toString() !== "") {
                    root._statusText = qsTr("Saved: %1").arg(actualLocation.toString().split("/").pop())
                    statusResetTimer.restart()
                }
            }

            onErrorOccurred: (error, errorString) => {
                root._statusText = errorString
                statusResetTimer.restart()
            }
        }
    }

    Timer {
        id:             statusResetTimer
        interval:       6000
        onTriggered:    root._statusText = ""
    }

    ColumnLayout {
        id:                 contentColumn
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
                    text:               qsTr("HDMI")
                    font.bold:          true
                    color:              qgcPal.text
                    Layout.alignment:   Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Elapsed time, visible while recording even when collapsed
                QGCLabel {
                    visible:            root.recording
                    text:               root._elapsedString(recorder.duration)
                    font.pointSize:     ScreenTools.smallFontPointSize
                    font.family:        ScreenTools.fixedFontFamily
                    color:              qgcPal.colorRed
                    Layout.alignment:   Qt.AlignVCenter
                }

                // Record / stop. Filled circle = idle, square = recording.
                Rectangle {
                    id:                 recordButton
                    Layout.alignment:   Qt.AlignVCenter
                    implicitWidth:      ScreenTools.defaultFontPixelHeight
                    implicitHeight:     implicitWidth
                    radius:             implicitWidth / 2
                    color:              "transparent"
                    border.color:       enabled ? qgcPal.text : qgcPal.colorGrey
                    border.width:       1
                    enabled:            root._selectedDevice !== null

                    Rectangle {
                        anchors.centerIn:   parent
                        width:              parent.width * (root.recording ? 0.42 : 0.58)
                        height:             width
                        radius:             root.recording ? 1 : width / 2
                        color:              recordButton.enabled ? qgcPal.colorRed : qgcPal.colorGrey

                        SequentialAnimation on opacity {
                            running:    root.recording
                            loops:      Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 600 }
                            NumberAnimation { to: 1.0;  duration: 600 }
                        }
                    }

                    MouseArea {
                        anchors.fill:   parent
                        enabled:        recordButton.enabled
                        onClicked:      root._toggleRecording()
                    }
                }
            }
        }

        QGCComboBox {
            id:                     deviceCombo
            visible:                root.expanded && root._devices.length > 0
            enabled:                !root.recording
            Layout.fillWidth:       true
            Layout.minimumWidth:    0
            model:                  root._devices.map(device => device.description)
            // Falls back to 0 to match _selectedDevice: without this the combo
            // shows blank until the user has picked a device once.
            currentIndex: {
                const index = root._devices.findIndex(device => device.description === panelSettings.deviceDescription)
                return index >= 0 ? index : 0
            }
            onActivated: (index) => { panelSettings.deviceDescription = root._devices[index].description }
        }

        Rectangle {
            visible:                root.expanded
            Layout.fillWidth:       true
            Layout.minimumWidth:    0
            Layout.preferredHeight: root._videoHeight
            color:                  "black"
            radius:                 ScreenTools.defaultFontPixelWidth / 4
            clip:                   true

            VideoOutput {
                id:             videoOutput
                anchors.fill:   parent
                fillMode:       VideoOutput.PreserveAspectFit
            }

            QGCLabel {
                anchors.centerIn:   parent
                visible:            root._devices.length === 0
                text:               qsTr("No capture device")
                color:              qgcPal.text
                font.pointSize:     ScreenTools.smallFontPointSize
            }
        }

        QGCLabel {
            visible:                root.expanded && root._statusText !== ""
            Layout.fillWidth:       true
            Layout.minimumWidth:    0
            text:                   root._statusText
            elide:                  Text.ElideMiddle
            font.pointSize:         ScreenTools.smallFontPointSize
            color:                  qgcPal.text
        }
    }
}
