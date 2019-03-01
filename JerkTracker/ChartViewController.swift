//
//  ChartViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/26/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIKit
import CoreMotion

final class Rhythm : NSObject {
    var values: [Double] = []
}

protocol ChartViewControllerDelegate : class {
    func newJerkRecorded(_ jerk: Rhythm)
}

final class ChartViewController : UIViewController {
    private var _chartView: ChartView!
    private var _motion: CMMotionManager!
    weak var delegate: ChartViewControllerDelegate?
    
    var jerks: [Rhythm] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupChartView()
        setupMotionUpdates()
    }
    
    private func setupChartView() {
        _chartView = ChartView(frame: view.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.yRange = (0...4)
        }
        view.addSubview(_chartView)
    }
    
    private var _isHighlighting = false
    
    private var _isTrackingJerk = false
    private var _jerkPatienceFrameCounter: Int = 0
    private let kJerkTriggerBoundary: Double = 0.3
    private let kJerkEndPatience: Int = 30
    
    private func setupMotionUpdates() {
        let motionUpdatesQueue = OperationQueue()
        motionUpdatesQueue.qualityOfService = .userInitiated
        
        _motion = CMMotionManager()
        _motion.deviceMotionUpdateInterval = 1 / 60.0
        var zPrevAcc: Double = 0
        var cntr = 0
        _motion.startDeviceMotionUpdates(to: motionUpdatesQueue) { [unowned self] (motion, error) in
            if let err = error {
                print("Error: \(err)")
                return
            }
            guard let a = motion?.userAcceleration else {
                print("Error: no data")
                return
            }
            let zJerk = abs(a.z - zPrevAcc)
            zPrevAcc = a.z
            
            if zJerk >= self.kJerkTriggerBoundary {
                self._jerkPatienceFrameCounter = 0
                if !self._isTrackingJerk {
                    self._isTrackingJerk = true
                    self.jerks.append(Rhythm())
                    self._chartView.startHighlighting()
                }
            } else if self._isTrackingJerk {
                self._jerkPatienceFrameCounter += 1
                if self._jerkPatienceFrameCounter >= self.kJerkEndPatience {
                    self._isTrackingJerk = false
                    self._chartView.stopHighlighting()
                    self.delegate?.newJerkRecorded(self.jerks.last!)
                }
            }
            
            if self._isTrackingJerk {
                self.jerks.last?.values.append(zJerk)
            }
            
            cntr += 1
            if cntr == 60 {
                cntr = 0
                print("JerksGotMotionData: \(Date())")
            }
            
            DispatchQueue.main.async {
                self._chartView.add(yCoord: zJerk)
            }
        }
    }
    
    func stop() {
        _motion.stopDeviceMotionUpdates()
        if _isTrackingJerk {
            _isTrackingJerk = false
            jerks.removeLast()
        }
    }
}
