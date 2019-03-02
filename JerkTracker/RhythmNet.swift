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
    
    static let kInputSize: Int = 120
    private let kNetName = "RhythmNet"
    private let kNEpochs = 200
    private let kBatchSize = 16
    private let kValidationPct = 0.2
    private let kLearningRate = 1e-3
    
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
    
    func saveParameters() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let netDirPath = (documentsPath as NSString).appendingPathComponent(kNetName)
        try! _model.save(to: netDirPath)
    }
    
    @discardableResult
    func restoreParameters() -> Bool  {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let netDirPath = (documentsPath as NSString).appendingPathComponent(kNetName)
        return try! _model.restore(from: netDirPath)
    }
    
    func train(rhythms: [Rhythm], labels: [String]) {
        let x = matrix(rhythms.map { $0.values })
        let classLabels = Array(Set(labels)).sorted()
        let numLabels = labels.map { classLabels.firstIndex(of: $0)! }
        _model.train(x: x,
                     y: onehot(vector(numLabels), nClasses: classLabels.count),
                     optimizer: AdamOptimizer(learningRate: kLearningRate),
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
