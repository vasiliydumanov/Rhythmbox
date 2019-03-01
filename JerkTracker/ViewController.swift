//
//  ViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import CoreMotion
import swix_ios

class ViewController: UIViewController {
    private var _motion: CMMotionManager!
    private var _charts: [ChartView]!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let chartsStack = UIStackView()
        chartsStack.translatesAutoresizingMaskIntoConstraints = false
        chartsStack.axis = .vertical
        chartsStack.distribution = .fillEqually
        view.addSubview(chartsStack)
        chartsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        chartsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        chartsStack.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        chartsStack.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        let chartColors: [UIColor] = [UIColor.red, UIColor.green, UIColor.blue]
            .map { $0.darkerColor(percent: 0.5) }
        _charts = []
        
        for color in chartColors {
            let chart = ChartView()
            chart.chartColor = color
            chart.yRange = (-1...4)
            chart.translatesAutoresizingMaskIntoConstraints = false
            chartsStack.addArrangedSubview(chart)
            _charts.append(chart)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let motionUpdatesQueue = OperationQueue()
        motionUpdatesQueue.qualityOfService = .userInitiated
        
        _motion = CMMotionManager()
        _motion.deviceMotionUpdateInterval = 1 / 60.0
        var xPrevAcc: Double = 0
        var yPrevAcc: Double = 0
        var zPrevAcc: Double = 0
        _motion.startDeviceMotionUpdates(to: motionUpdatesQueue) { [unowned self] (motion, error) in
            if let err = error {
                print("Error: \(err)")
                return
            }
            guard let a = motion?.userAcceleration else {
                print("Error: no data")
                return
            }
            print("x = \(a.x), y = \(a.y), z = \(a.z)")
            let xJerk = abs(a.x - xPrevAcc)
            let yJerk = abs(a.y - yPrevAcc)
            let zJerk = abs(a.z - zPrevAcc)
            xPrevAcc = a.x
            yPrevAcc = a.y
            zPrevAcc = a.z
            DispatchQueue.main.async {
                for (a, chart) in zip([xJerk, yJerk, zJerk], self._charts) {
                    chart.add(yCoord: a)
                }
            }
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

