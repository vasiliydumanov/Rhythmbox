//
//  JerkNet.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/1/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import SwiftMLP
import swix
import Zip

extension Notification.Name {
    static let rhythmNetParamsUpdated = Notification.Name("rhythm_net_params_updated")
}

final class CancelTrainingCallback : Callback {
    override var priority: Callback.Priority {
        return .begin
    }
    
    let shouldCancel: () -> Bool
    
    init(shouldCancel: @escaping () -> Bool) {
        self.shouldCancel = shouldCancel
    }
    
    override func onBatchEnd() -> Bool {
        return !shouldCancel()
    }
}

final class RhythmNet {
    typealias Prediction = (cls: Int, prob: Double)
    
    static let kInputSize: Int = 120
    static let kNetName = "RhythmNet"
    static let kNEpochs = 200
    private let kBatchSize = 16
    private let kValidationPct = 0.2
    private let kLearningRate = 1e-3
    
    private let _model: Model
    private static let _queue = DispatchQueue(label: "rhythm_net_queue")
    
    private var _isTraining = false
    private var _shouldCancelTraining = false
    
    init() {
        _model = Model([
            Dense(units: 200),
            Relu(),
            Dense(units: 4),
            Softmax()
            ])
        _model.compile(loss: SoftmaxCrossentropy())
    }
    
    func saveParameters() {
        RhythmNet._queue.sync { [unowned self] in
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let netDirPath = (documentsPath as NSString).appendingPathComponent(RhythmNet.kNetName)
            try! self._model.save(to: netDirPath)
            NotificationCenter.default.post(name: .rhythmNetParamsUpdated, object: nil)
        }
    }
    
    @discardableResult
    func restoreParameters() -> Bool  {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let netDirPath = (documentsPath as NSString).appendingPathComponent(RhythmNet.kNetName)
        return try! self._model.restore(from: netDirPath)
    }
    
    static func zipParams() throws -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let netDirPath = (documentsPath as NSString).appendingPathComponent(kNetName)
        let netDirContents = try FileManager.default.contentsOfDirectory(atPath: netDirPath)
        let netDirContentsUrls = netDirContents.map { c in
            URL(fileURLWithPath: (netDirPath as NSString).appendingPathComponent(c))
        }
        let archiveUrl = try Zip.quickZipFiles(netDirContentsUrls, fileName: "RhythmNetArchive")
        return archiveUrl
    }
    
    static func restoreDefaultParamsIfNeeded() throws {
        try RhythmNet._queue.sync {
            let fm = FileManager.default
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let netDirPath = (documentsPath as NSString).appendingPathComponent(kNetName)
            guard !fm.fileExists(atPath: netDirPath) else { return }
            try fm.createDirectory(atPath: netDirPath, withIntermediateDirectories: false, attributes: nil)
            let defaultParamsFile = (Bundle.main.resourcePath! as NSString).appendingPathComponent("RhythmNetWeightsDefault.zip")
            try Zip.unzipFile(
                URL(fileURLWithPath: defaultParamsFile),
                destination: URL(fileURLWithPath: netDirPath),
                overwrite: true,
                password: nil)
        }
    }
    
    func train(rhythms: [Rhythm], labels: [Int], onEpochEnd: @escaping Logging.OnEpochEnd) {
        let x = matrix(rhythms.map { $0.data })
        let nClasses = Set(labels).count
        _isTraining = true
        self._model.train(x: x,
                          y: onehot(vector(labels), nClasses: nClasses),
                          optimizer: AdamOptimizer(learningRate: self.kLearningRate),
                          nEpochs: RhythmNet.kNEpochs,
                          batchSize: self.kBatchSize,
                          validationPct: self.kValidationPct,
                          metrics: [Accuracy()],
                          callbacks: [EarlyStopping(patience: 20),
                                      Logging(onEpochEnd: onEpochEnd),
                                      CancelTrainingCallback(shouldCancel: { [unowned self] in self._shouldCancelTraining })])
        _isTraining = false
        _shouldCancelTraining = false
    }
    
    func cancelTraining() {
        guard _isTraining else { return }
        _shouldCancelTraining = true
    }
    
    func predict(rhythm: Rhythm) -> Prediction {
        var prediction: Prediction!
        RhythmNet._queue.sync {
            var rhythmData = rhythm.data
            guard rhythmData.count <= RhythmNet.kInputSize else {
                prediction = (RhythmType.noise.rawValue, 1.0)
                return
            }
            rhythmData = [Double](repeating: 0, count: RhythmNet.kInputSize - rhythmData.count) + rhythmData
            let rhythmMat = matrix([rhythmData])
            let probs = _model.predict(rhythmMat)
            let cls = Int(argmax(probs, axis: 1)[0])
            prediction = (cls, probs[0, cls])
        }
        return prediction
    }
    
    func reset() {
        RhythmNet._queue.sync { [weak self] in
            self?._model.reset()
        }
    }
}
