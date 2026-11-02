import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id: root

    property string warningText

    signal suppressWarningRequested()

    buttons: Dialog.Ok

    onAccepted: {
        if (suppressWarningCheckBox.checked) {
            suppressWarningRequested()
        }
    }

    ColumnLayout {
        QGCLabel {
            Layout.preferredWidth: Math.max(root.maxContentAvailableWidth / (ScreenTools.isMobile ? 2 : 3),
                                            root.headerMinWidth)
            text: root.warningText
            wrapMode: Text.WordWrap
        }

        QGCCheckBox {
            id: suppressWarningCheckBox
            text: qsTr("Don't show this warning again")
        }
    }
}
