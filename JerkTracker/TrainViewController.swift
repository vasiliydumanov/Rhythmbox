//
//  TrainViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/21/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIKit
import TensorSwift


final class TrainViewController : UIViewController {
    private let _computationQueue = DispatchQueue(label: "compute_queue")
    private var _computeItem: DispatchWorkItem!
    private var _saveItem: UIBarButtonItem!
    private var _logTextView: UITextView!
    
    private var _nn: SimpleNeuralNet!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBar()
        setupTextView()
        trainModel()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        _computeItem?.cancel()
    }
    
    private func setupNavBar() {
        _saveItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveParameters)).then {
            $0.isEnabled = false
        }
        navigationItem.rightBarButtonItem = _saveItem
    }
    
    private func setupTextView() {
        _logTextView = UITextView(frame: view.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.backgroundColor = .black
            $0.textColor = .white
            $0.isEditable = false
            $0.isSelectable = false
            $0.text = ""
            $0.font = UIFont.systemFont(ofSize: 16)
        }
        view.addSubview(_logTextView)
    }
    
    private func loadData() -> (x: [[Float]], y: [Float], numberOfClasses: Int) {
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let jerksDirPath = (documentsPath as NSString).appendingPathComponent("Jerks")
        let jerksFiles = try! fm.contentsOfDirectory(atPath: jerksDirPath)
        
        var x: [[Float]] = []
        var y: [Float] = []
        
        var maxJerkLength = 0
        for (idx, file) in jerksFiles.enumerated() {
            let filePath = (jerksDirPath as NSString).appendingPathComponent(file)
            let fileContents = try! String(contentsOfFile: filePath, encoding: .utf8)
            for jerkStr in fileContents.split(separator: "\n") {
                let jerkData = jerkStr.split(separator: ",").map { Float($0)! }
                if jerkData.count > maxJerkLength {
                    maxJerkLength = jerkData.count
                }
                x.append(jerkData)
                y.append(Float(idx))
            }
        }
        
        for i in 0..<x.count {
            let padding: [Float] = Array(repeating: 0, count: maxJerkLength - x[i].count)
            x[i] = padding + x[i]
        }
        
        var shuffledIdx = Array(0..<x.count)
        shuffledIdx.shuffle()
        
        var xShuffled: [[Float]] = []
        var yShuffled: [Float] = []
        
        for idx in shuffledIdx {
            xShuffled.append(x[idx])
            yShuffled.append(y[idx])
        }
        
        return (xShuffled, yShuffled, jerksFiles.count)
    }
    
    private func trainModel(nEpochs: Int = 10, batchSize: Int = 16, valPct: Float = 0.1) {
        _computeItem = DispatchWorkItem {
            let (x, y, numberOfClasses) = self.loadData()
            
            let valTo = Int(Float(x.count) * valPct)
            let xVal = Array(x[0..<valTo])
            let yVal = Array(y[0..<valTo])
            let xTrain = Array(x[valTo..<(x.count - 1)])
            let yTrain = Array(y[valTo..<(x.count - 1)])
            
            let xTrainBatches = xTrain.chunked(minSize: batchSize)
            let yTrainBatches = yTrain.chunked(minSize: batchSize)
            
            self._nn = SimpleNeuralNet(inputUnits: x[0].count, l1Units: 200, l2Units: 2)
            
            for epoch in 0...nEpochs {
                var logStr: String = ""
                for (idx, (xBatch, yBatch)) in zip(xTrainBatches, yTrainBatches).enumerated() {
                    if epoch > 0 {
                        self._nn.trainBatch(epoch: epoch, xRaw: xBatch, yRaw: yBatch, xValRaw: xVal, yValRaw: yVal, numberOfClasses: numberOfClasses, learningRate: 0.001)
                    }
                    if idx == xTrainBatches.count - 1 {
                        let (trainLoss, trainAcc) = self._nn.evaluate(xRaw: xBatch, yRaw: yBatch, numberOfClasses: numberOfClasses)
                        logStr += "Epoch: \(epoch)/\(nEpochs), Train Loss: \(trainLoss), Train Acc: \(trainAcc)"
                    }
                }
                let (valLoss, valAcc) = self._nn.evaluate(xRaw: xVal, yRaw: yVal, numberOfClasses: numberOfClasses)
                logStr += ", Val Loss: \(valLoss), Val Acc: \(valAcc)\n\n"
                DispatchQueue.main.async {
                    self._logTextView.text += logStr
                }
            }
            DispatchQueue.main.async {
                self._saveItem.isEnabled = true
            }
            self._computeItem = nil
        }
        _computationQueue.async(execute: _computeItem)
    }
    
    @objc private func saveParameters() {
        _nn.saveParameters()
        navigationController?.popViewController(animated: true)
    }
}
