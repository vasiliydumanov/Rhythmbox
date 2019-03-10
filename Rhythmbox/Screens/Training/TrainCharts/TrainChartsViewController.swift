//
//  TrainChartsViewController.swift
//  Rhythmbox
//
//  Created by Vasiliy Dumanov on 3/7/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIKit
import Charts
import SwiftMLP

private struct ChartModel {
    let name: String
    let keysAndColors: [(key: LogKey, color: UIColor)]
    let minMax: (min: Double?, max: Double?)
}

final class TrainChartsViewController : TrainTabViewController {
    private let kChartModels: [ChartModel] = [
        ChartModel(name: "Loss",
                   keysAndColors: [(.trainLoss, UIColor("#f44336")), (.valLoss, UIColor("#1976d2"))],
                  minMax: (0, nil)),
        ChartModel(name: "Accuracy",
                   keysAndColors: [(.trainAccuracy, UIColor("#43a047")), (.valAccuracy, UIColor("#ff9800"))],
                   minMax: (0, 1))
    ]
    private var _logs: [Log] = []
    private var _charts: [LineChartView] = []
    private var _chartsData: [LineChartData] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCharts()
    }
    
    private func setupCharts() {
        let chartsStack = UIStackView().then {
            $0.axis = .vertical
            $0.spacing = 40
            $0.distribution = .fillEqually
        }
        view.addSubview(chartsStack)
        chartsStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20).priority(.low)
            make.trailing.equalToSuperview().offset(-20).priority(.low)
            make.top.equalToSuperview().offset(20).priority(.low)
            make.bottom.equalToSuperview().offset(-20).priority(.low)
        }
        
        for cm in kChartModels {
            let chart = LineChartView().then {
                $0.rightAxis.enabled = false
                $0.dragYEnabled = false
                $0.scaleYEnabled = false
                $0.pinchZoomEnabled = false
            }
            _charts.append(chart)
            
            chart.legend.do {
                $0.textColor = .white
            }
            chart.xAxis.do {
                $0.labelFont = .systemFont(ofSize: 11)
                $0.labelTextColor = .white
                $0.drawAxisLineEnabled = true
                $0.labelPosition = .bottom
            }
            chart.leftAxis.do {
                $0.labelFont = .systemFont(ofSize: 11)
                $0.labelTextColor = .white
                $0.drawAxisLineEnabled = true
                if let min = cm.minMax.min {
                    $0.axisMinimum = min
                }
                if let max = cm.minMax.max {
                    $0.axisMaximum = max
                }
            }
            
            var datasets: [LineChartDataSet] = []
            for (key, color) in cm.keysAndColors {
                let dataset = LineChartDataSet(values: [], label: key.rawValue).then {
                    $0.drawCirclesEnabled = false
                    $0.drawValuesEnabled = false
                    $0.setDrawHighlightIndicators(false)
                    $0.setColor(color)
                    $0.lineWidth = 2
                }
                datasets.append(dataset)
            }
            let data = LineChartData(dataSets: datasets)
            _chartsData.append(data)
            
            chart.data = data
            chartsStack.addArrangedSubview(chart)
        }
    }
    
    override func onTrainBegan() {
        _chartsData.forEach {
            $0.dataSets.forEach { $0.clear() }
            $0.calcMinMax()
        }
        _charts.forEach {
            $0.dragXEnabled = false
            $0.scaleXEnabled = false
        }
    }
    
    override func onEpochEnd(epoch: Int, log: Log) {
        for (chartIdx, cm) in kChartModels.enumerated() {
            for (offset: keyIdx, element: (key: key, color: _)) in cm.keysAndColors.enumerated() {
                let entry = ChartDataEntry(x: Double(epoch), y: log[key] as! Double)
                _chartsData[chartIdx].addEntry(entry, dataSetIndex: keyIdx)
            }
            _charts[chartIdx].notifyDataSetChanged()
        }
    }
    
    override func onTrainEnded() {
        _charts.forEach {
            $0.dragXEnabled = true
            $0.scaleXEnabled = true
        }
    }
}
