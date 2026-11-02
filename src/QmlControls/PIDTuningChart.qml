import QtQuick
import QtGraphs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Column {
    QGCPalette { id: qgcPal }

    property var axisData
    property string pageTitle
    property string unit
    property double chartDisplaySec: 8

    readonly property int _tickSeparation: 5
    readonly property var _seriesColors: ["#21be2b", "#c62828", "#1565c0", "#f9a825", "#6a1b9a", "#00838f"]
    property var _legendModel: []

    function _adjustYAxisMin(newValue) {
        var newMin = Math.min(yAxis.min, newValue)
        if (newMin % 5 != 0) {
            newMin -= 5
            newMin = Math.floor(newMin / _tickSeparation) * _tickSeparation
        }
        yAxis.min = newMin
    }

    function _adjustYAxisMax(newValue) {
        var newMax = Math.max(yAxis.max, newValue)
        if (newMax % 5 != 0) {
            newMax += 5
            newMax = Math.floor(newMax / _tickSeparation) * _tickSeparation
        }
        yAxis.max = newMax
    }

    function resetGraph() {
        for (var i = 0; i < chart.seriesList.length; ++i) {
            chart.seriesList[i].clear()
        }
        xAxis.min = 0
        xAxis.max = 0
        yAxis.min = 0
        yAxis.max = 0
    }

    function _createSeries() {
        while (chart.seriesList.length > 0) {
            chart.removeSeries(chart.seriesList[0])
        }

        var legendItems = []
        axisData.plot.forEach(function(plot, index) {
            var color = _seriesColors[index % _seriesColors.length]
            var series = lineSeriesComponent.createObject(chart, {name: plot.name, color: color})
            chart.addSeries(series)
            legendItems.push({name: plot.name, color: color})
        })
        _legendModel = legendItems
    }

    function appendData(plotData, timeSeconds, firstPoint) {
        xAxis.max = timeSeconds
        xAxis.min = timeSeconds - chartDisplaySec

        for (var i = 0; i < plotData.length; ++i) {
            var value = plotData[i].value
            if (!isNaN(value)) {
                chart.seriesList[i].append(timeSeconds, value)
                if (firstPoint) {
                    yAxis.min = value
                    yAxis.max = value
                } else {
                    _adjustYAxisMin(value)
                    _adjustYAxisMax(value)
                }

                var minSec = timeSeconds - 3 * 60
                while (chart.seriesList[i].count > 0 && chart.seriesList[i].at(0).x < minSec) {
                    chart.seriesList[i].remove(0)
                }
            }
        }
    }

    Component {
        id: lineSeriesComponent
        LineSeries { }
    }

    Component.onCompleted: _createSeries()

    QGCLabel {
        id: chartTitle
        text: axisData.name + " " + pageTitle
        font.pointSize: ScreenTools.smallFontPointSize
        anchors.horizontalCenter: parent.horizontalCenter
    }

    GraphsView {
        id: chart
        width: parent.width
        height: parent.height - chartTitle.height - legendRow.height

        theme: GraphsTheme {
            colorScheme: qgcPal.globalTheme === QGCPalette.Light ? GraphsTheme.ColorScheme.Light : GraphsTheme.ColorScheme.Dark
            plotAreaBackgroundColor: qgcPal.window
            grid.mainColor: Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.5)
            grid.subColor: Qt.rgba(qgcPal.text.r, qgcPal.text.g, qgcPal.text.b, 0.3)
            grid.mainWidth: 1
            labelBackgroundVisible: false
            labelTextColor: qgcPal.text
        }

        axisX: ValueAxis {
            id: xAxis
            min: 0
            max: 0
            labelFormat: "%.1f"
            titleText: ScreenTools.isShortScreen ? "" : qsTr("sec")
            titleFont.pointSize: ScreenTools.smallFontPointSize
        }

        axisY: ValueAxis {
            id: yAxis
            min: 0
            max: 10
            titleText: unit
            tickInterval: _tickSeparation
            titleFont.pointSize: ScreenTools.smallFontPointSize
        }
    }

    Row {
        id: legendRow
        spacing: ScreenTools.defaultFontPixelWidth / 2
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            model: _legendModel
            Row {
                spacing: ScreenTools.defaultFontPixelWidth / 3
                Rectangle {
                    width: ScreenTools.defaultFontPixelHeight / 2
                    height: ScreenTools.defaultFontPixelHeight / 4
                    color: modelData.color
                    anchors.verticalCenter: parent.verticalCenter
                }
                QGCLabel {
                    text: modelData.name
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }
    }

}
