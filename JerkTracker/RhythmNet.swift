//
//  JerkNet.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/1/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import SwiftMLP
import swix_ios


final class RhythmNet {
    typealias Prediction = (label: String, prob: Double)
    
    private let kInputSize: Int = 120
    private let kNetName = "RhythmNet"
    private let kNEpochs = 100
    private let kBatchSize = 32
    private let kValidationPct = 0.1
    
    private let _model: Model
    
    init() {
        _model = Model([
            Dense(units: 200),
            Relu(),
            Dense(units: 2),
            Softmax()
            ])
        _model.compile(loss: SoftmaxCrossentropy())
    }
    
    private func saveParameters() {
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let netDirPath = (documentsPath as NSString).appendingPathComponent(kNetName)
        try! _model.save(to: netDirPath)
    }
    
    func restoreParameters() -> Bool  {
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let netDirPath = (documentsPath as NSString).appendingPathComponent(kNetName)
        return try! _model.restore(from: netDirPath)
    }
    
    func train(rhythms: [Rhythm], labels: [String]) {
        let x = matrix(rhythms.map { $0.values })
        let y = vector(labels.enumerated().map { $0.offset })
        _model.train(x: x,
                     y: onehot(y, nClasses: unique(y).count),
                     optimizer: SGDOptimizer(),
                     nEpochs: kNEpochs,
                     batchSize: kBatchSize,
                     validationPct: kValidationPct,
                     metrics: [Accuracy()])
    }
    
    func predict(rhythm: Rhythm, classLabels: [String]) -> Prediction {
        let rhythmMat = matrix([rhythm.values])
        let probs = _model.predict(rhythmMat)
        let clsId = Int(argmax(probs, axis: 1)[0])
        return (classLabels[clsId], probs[0, clsId])
    }
}
