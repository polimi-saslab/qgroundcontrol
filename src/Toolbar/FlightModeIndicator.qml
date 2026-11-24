import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:                     control
    Layout.preferredWidth:  mainLayout.width

    property bool   showIndicator:          true
    property bool   waitForParameters:      false

    property real fontPointSize:    ScreenTools.largeFontPointSize
    property var  activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property bool allowEditMode:    true
    property bool editMode:         false

    property bool _isVTOL:          activeVehicle ? activeVehicle.vtol : false
    property bool _vtolInFWDFlight: activeVehicle ? activeVehicle.vtolInFwdFlight : false
    readonly property bool _canTransition: activeVehicle &&
        (activeVehicle.vtolState === Vehicle.MultiCopter || activeVehicle.vtolState === Vehicle.FixedWing)
    readonly property bool _vtolTransitioning: activeVehicle &&
        (activeVehicle.vtolState === Vehicle.TransitionToFixedWing ||
         activeVehicle.vtolState === Vehicle.TransitionToMultiCopter)
    readonly property color _vtolTransitionColor: qgcPal.colorBlue
    readonly property string _vtolStateText: {
        if (!activeVehicle) {
            return ""
        }
        switch (activeVehicle.vtolState) {
        case Vehicle.MultiCopter:
            return qsTr("Multicopter")
        case Vehicle.FixedWing:
            return qsTr("Fixed-wing")
        case Vehicle.TransitionToFixedWing:
            return qsTr("MC → FW")
        case Vehicle.TransitionToMultiCopter:
            return qsTr("FW → MC")
        default:
            return qsTr("VTOL state unknown")
        }
    }
    property var  _vehicleInAir:    activeVehicle ? activeVehicle.airborne || activeVehicle.landing : false

    QGCPalette { id: qgcPal }

    RowLayout {
        id:                     mainLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing:                ScreenTools.defaultFontPixelWidth / 2

        QGCColoredImage {
            id:                     flightModeIcon
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 3
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            color:                  qgcPal.text
            source:                 "/qmlimages/FlightModesComponentIcon.png"
        }

        QGCLabel {
            id:                 flightModeLabel
            text:               activeVehicle ? activeVehicle.flightMode : qsTr("N/A", "No data to display")
            color:              qgcPal.text
            font.pointSize:     fontPointSize

        }

        QGCLabel {
            Layout.alignment:   Qt.AlignVCenter
            text:               "|"
            color:              qgcPal.text
            font.pointSize:     control.fontPointSize
            visible:            control._isVTOL
        }

        QGCLabel {
            id:                 vtolModeLabel
            Layout.alignment:   Qt.AlignVCenter
            text:               control._vtolStateText
            color:              control._vtolTransitioning ? control._vtolTransitionColor : qgcPal.text
            font.pointSize:     control.fontPointSize
            wrapMode:           Text.NoWrap
            visible:            control._isVTOL
        }
    }

    MouseArea {
        anchors.fill:   mainLayout
        onClicked:      mainWindow.showIndicatorDrawer(drawerComponent, control)
    }

    Component {
        id: drawerComponent

        ToolIndicatorPage {
            showExpand:         true
            waitForParameters:                  false
            expandedComponentWaitForParameters: true

            contentComponent:    flightModeContentComponent
            expandedComponent:   flightModeExpandedComponent

            onExpandedChanged: {
                if (!expanded) {
                    editMode = false
                }
            }
        }
    }

    Component {
        id: flightModeContentComponent

        ColumnLayout {
            id:         modeColumn
            spacing:    ScreenTools.defaultFontPixelWidth / 2

            property var    activeVehicle:            QGroundControl.multiVehicleManager.activeVehicle
            property var    flightModeSettings:       QGroundControl.settingsManager.flightModeSettings
            property var    hiddenFlightModesFact:    null
            property var    hiddenFlightModesList:    []

            Component.onCompleted: {
                // Hidden flight modes are classified by firmware and vehicle class
                var hiddenFlightModesPropPrefix
                if (activeVehicle.px4Firmware) {
                    hiddenFlightModesPropPrefix = "px4HiddenFlightModes"
                } else if (activeVehicle.apmFirmware) {
                    hiddenFlightModesPropPrefix = "apmHiddenFlightModes"
                } else {
                    control.allowEditMode = false
                }
                if (control.allowEditMode) {
                    var hiddenFlightModesProp = hiddenFlightModesPropPrefix + activeVehicle.vehicleClassInternalName()
                    if (flightModeSettings.hasOwnProperty(hiddenFlightModesProp)) {
                        hiddenFlightModesFact = flightModeSettings[hiddenFlightModesProp]
                        // Split string into list of flight modes
                        if (hiddenFlightModesFact && hiddenFlightModesFact.value !== "") {
                            hiddenFlightModesList = hiddenFlightModesFact.value.split(",")
                        }
                    } else {
                        control.allowEditMode = false
                    }
                }
                hiddenModesLabel.calcVisible()
            }

            Connections {
                target: control
                function onEditModeChanged() {
                    if (editMode) {
                        for (var i=0; i<modeRepeater.count; i++) {
                            var button      = modeRepeater.itemAt(i).children[0]
                            var checkBox    = modeRepeater.itemAt(i).children[1]

                            checkBox.checked = !hiddenFlightModesList.find(item => { return item === button.text } )
                        }
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               control.activeVehicle ? control.activeVehicle.vtolStateString : ""
                color:              control._vtolTransitioning ? control._vtolTransitionColor : qgcPal.text
                visible:            control._isVTOL
                wrapMode:           Text.WordWrap
            }

            QGCDelayButton {
                id:                 vtolTransitionButton
                Layout.fillWidth:   true
                text:               control._canTransition ?
                                        (control._vtolInFWDFlight ? qsTr("Transition to multicopter") : qsTr("Transition to fixed-wing")) :
                                        (control.activeVehicle ? control.activeVehicle.vtolStateString : "")
                visible:            _isVTOL && _vehicleInAir
                enabled:            control._canTransition

                onActivated: {
                    if (control.activeVehicle && control._canTransition) {
                        control.activeVehicle.vtolInFwdFlight = !control._vtolInFWDFlight
                    }
                    mainWindow.closeIndicatorDrawer()
                }
            }

            Repeater {
                id:     modeRepeater
                model:  activeVehicle ? activeVehicle.flightModes : []

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    visible: editMode || !hiddenFlightModesList.find(item => { return item === modelData } )

                    QGCDelayButton {
                        id:                 modeButton
                        text:               modelData
                        delay:              flightModeSettings.requireModeChangeConfirmation.rawValue ? defaultDelay : 0
                        Layout.fillWidth:   true

                        onActivated: {
                            if (editMode) {
                                parent.children[1].toggle()
                                parent.children[1].clicked()
                            } else {
                                //var controller = globals.guidedControllerFlyView
                                //controller.confirmAction(controller.actionSetFlightMode, modelData)
                                activeVehicle.flightMode = modelData
                                mainWindow.closeIndicatorDrawer()
                            }
                        }
                    }

                    QGCCheckBoxSlider {
                        visible: editMode

                        onClicked: {
                            hiddenFlightModesList = []
                            for (var i=0; i<modeRepeater.count; i++) {
                                var checkBox = modeRepeater.itemAt(i).children[1]
                                if (!checkBox.checked) {
                                    hiddenFlightModesList.push(modeRepeater.model[i])
                                }
                            }
                            hiddenFlightModesFact.value = hiddenFlightModesList.join(",")
                            hiddenModesLabel.calcVisible()
                        }
                    }
                }
            }

            QGCLabel {
                id:                     hiddenModesLabel
                text:                   qsTr("Some Modes Hidden")
                Layout.fillWidth:       true
                font.pointSize:         ScreenTools.smallFontPointSize
                horizontalAlignment:    Text.AlignHCenter
                visible:                false

                function calcVisible() {
                    hiddenModesLabel.visible = hiddenFlightModesList.length > 0
                }
            }
        }
    }

    Component {
        id: flightModeExpandedComponent

        ColumnLayout {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 60
            spacing:                margins / 2

            property var  qgcPal:               QGroundControl.globalPalette
            property real margins:              ScreenTools.defaultFontPixelHeight
            property var  flightModeSettings:   QGroundControl.settingsManager.flightModeSettings

            Loader {
                Layout.fillWidth:   true
                source:             _activeVehicle.expandedToolbarIndicatorSource("FlightMode")
            }

            SettingsGroupLayout {
                Layout.fillWidth:  true

                FactCheckBoxSlider {
                    Layout.fillWidth:   true
                    text:               qsTr("Click and Hold to Confirm Mode Change")
                    fact:               flightModeSettings.requireModeChangeConfirmation
                }

                RowLayout {
                    Layout.fillWidth:   true
                    enabled:            control.allowEditMode

                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               qsTr("Edit Displayed Flight Modes")
                    }

                    QGCCheckBoxSlider {
                        onClicked: control.editMode = checked
                    }
                }

                LabelledButton {
                    Layout.fillWidth:   true
                    label:              qsTr("Flight Modes")
                    buttonText:         qsTr("Configure")
                    visible:            _activeVehicle.autopilotPlugin.knownVehicleComponentAvailable(AutoPilotPlugin.KnownFlightModesVehicleComponent) &&
                                            QGroundControl.corePlugin.showAdvancedUI

                    onClicked: {
                        mainWindow.showKnownVehicleComponentConfigPage(AutoPilotPlugin.KnownFlightModesVehicleComponent)
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }
        }
    }
}
