//
//  RhythmTracker.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/5/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import CoreMotion
import Then

final class Rhythm : NSObject {
    var data: [Double] = []
}

@objc protocol RhythmTrackerDelegate : class {
    @objc optional func rhythmTrackingBegan()
    @objc optional func rhythmTrackingEnded(_ rhythm: Rhythm)
    @objc optional func gotJerkData(_ jerk: Double)
}

final class RhythmTracker : Then {
    static let kTrackingFreq: Double = 1.0 / 60.0
    static let kTriggerBoundary: Double = 0.3
    static let kEndPatience: Int = 30
    
    private var _isTracking = false
    private var _motion: CMMotionManager!
    private var _queue: OperationQueue!
    private var _rhythmPatienceFrameCounter: Int = 0
    private var _trackedRhythm: Rhythm?
    
    weak var delegate: RhythmTrackerDelegate?
    
    init() {
        _motion = CMMotionManager().then {
            $0.deviceMotionUpdateInterval = RhythmTracker.kTrackingFreq
        }
        _queue = OperationQueue().then {
            $0.qualityOfService = .userInitiated
        }
    }
    
    func start() {
        guard !_isTracking else { return }
        print("Start tracking")
        _isTracking = true
        var zPrevAcc: Double = 0
        _motion.startDeviceMotionUpdates(to: _queue) { [weak self] (motion, error) in
            self?.got(motion: motion, error: error, zPrevAcc: &zPrevAcc)
        }
    }
    
    private func got(motion: CMDeviceMotion?, error: Error?, zPrevAcc: inout Double) {
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
        
        if zJerk >= RhythmTracker.kTriggerBoundary {
            _rhythmPatienceFrameCounter = 0
            if _trackedRhythm == nil {
                _trackedRhythm = Rhythm()
                delegate?.rhythmTrackingBegan?()
            }
        } else if let rhythm = _trackedRhythm {
            _rhythmPatienceFrameCounter += 1
            if _rhythmPatienceFrameCounter >= RhythmTracker.kEndPatience {
                delegate?.rhythmTrackingEnded?(rhythm)
                _trackedRhythm = nil
            }
        }
        
        if _trackedRhythm != nil {
            _trackedRhythm?.data.append(zJerk)
        }
        
        delegate?.gotJerkData?(zJerk)
    }
    
    func stop() {
        guard _isTracking else { return }
        print("Stop tracking")
        _isTracking = false
        _motion.stopDeviceMotionUpdates()
        _trackedRhythm = nil
        _rhythmPatienceFrameCounter = 0
    }
    
    deinit {
        guard _isTracking else { return }
        stop()
    }
}
