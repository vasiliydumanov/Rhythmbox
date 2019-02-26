//
//  SimpleNeuralNet.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/21/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import TensorSwift
import GameplayKit

typealias ForwardPassResult = (z1: Tensor, a1: Tensor, z2: Tensor, a2: Tensor)
typealias EvaluationResult = (loss: Float, accuracy: Float)

class SimpleNeuralNet {
    private let _inputUnits: Int
    private let _l1Units: Int
    private let _l2Units: Int
    
    private var _w1: Tensor
    private var _w2: Tensor
    private var _b1: Tensor
    private var _b2: Tensor
    
    private var _mw1: Tensor!
    private var _mw2: Tensor!
    private var _mb1: Tensor!
    private var _mb2: Tensor!
    
    private var _vw1: Tensor!
    private var _vw2: Tensor!
    private var _vb1: Tensor!
    private var _vb2: Tensor!
    
    init() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let modelDirPath = (documentsPath as NSString).appendingPathComponent("ModelParameters")
        let paramFiles = try! FileManager.default.contentsOfDirectory(atPath: modelDirPath)
        var tensors: [Tensor] = []
        for file in paramFiles {
            let filepath = (modelDirPath as NSString).appendingPathComponent("\(file).csv")
            let contents = try! String(contentsOfFile: filepath, encoding: .utf8)
            let tensor = Tensor.from(csvString: contents)
            tensors.append(tensor)
        }
        
        let units = tensors[0]
        _inputUnits = Int(units[0, 0])
        _l1Units = Int(units[0, 1])
        _l2Units = Int(units[0, 2])
        
        _w1 = tensors[1]
        _w2 = tensors[2]
        _b1 = tensors[3]
        _b2 = tensors[4]
    }
    
    init(inputUnits: Int, l1Units: Int, l2Units: Int) {
        _inputUnits = inputUnits
        _l1Units = l1Units
        _l2Units = l2Units
        
        let w1Shape = Shape([Dimension(_inputUnits), Dimension(_l1Units)])
        let w2Shape = Shape([Dimension(_l1Units), Dimension(_l2Units)])
        let b1Shape = Shape([1, Dimension(_l1Units)])
        let b2Shape = Shape([1, Dimension(_l2Units)])
        
        _w1 = Tensor.glorot(fanIn: _inputUnits, fanOut: _l1Units, shape: w1Shape)
        _w2 = Tensor.glorot(fanIn: _l1Units, fanOut: _l2Units, shape: w2Shape)
        _b1 = Tensor(shape: b1Shape, element: 0)
        _b2 = Tensor(shape: b2Shape, element: 0)
        
        initializeOptimizerVars()
    }
    
    init(_ tensors: [Tensor]) {
        _inputUnits = 2
        _l1Units = 3
        _l2Units = 2
        
        let b1Shape = Shape([1, Dimension(_l1Units)])
        let b2Shape = Shape([1, Dimension(_l2Units)])
        
        _w1 = tensors[0]
        _w2 = tensors[1]
        _b1 = Tensor(shape: b1Shape, element: 0)
        _b2 = Tensor(shape: b2Shape, element: 0)
        
        initializeOptimizerVars()
    }
    
    private func initializeOptimizerVars() {
        _mw1 = Tensor(shape: _w1.shape, element: 0)
        _mw2 = Tensor(shape: _w2.shape, element: 0)
        _mb1 = Tensor(shape: _b1.shape, element: 0)
        _mb2 = Tensor(shape: _b2.shape, element: 0)
        
        _vw1 = Tensor(shape: _w1.shape, element: 0)
        _vw2 = Tensor(shape: _w2.shape, element: 0)
        _vb1 = Tensor(shape: _b1.shape, element: 0)
        _vb2 = Tensor(shape: _b2.shape, element: 0)
    }
    
    func forwardPass(_ x: Tensor) -> ForwardPassResult {
        var z1 = x.matmul(_w1)
        for i in 0..<z1.rows {
            for k in 0..<z1.cols {
                z1[i, k] += _b1[0, k]
            }
        }
        let a1 = z1.relu()
        var z2 = a1.matmul(_w2)
        for i in 0..<z2.rows {
            for k in 0..<z2.cols {
                z2[i, k] += _b2[0, k]
            }
        }
        let a2 = z2.softmax()
        return (z1, a1, z2, a2)
    }
    
    func trainBatch(epoch: Int, xRaw: [[Float]], yRaw: [Float], xValRaw: [[Float]], yValRaw: [Float], numberOfClasses: Int, learningRate: Float = 0.01) {
        let x = Tensor(shape: Shape([Dimension(xRaw.count), Dimension(xRaw[0].count)]), elements: xRaw.flatMap { $0 })
        var y = Tensor(shape: Shape([Dimension(xRaw.count)]), elements: yRaw)
        y = y.onehot(numberOfClasses: numberOfClasses)
        
        let (z1, a1, z2, a2) = forwardPass(x)
        
        var w1grads: [Tensor] = []
        var w2grads: [Tensor] = []
        var b1grads: [Tensor] = []
        var b2grads: [Tensor] = []
        for b in 0..<x.rows {
            var dldw2 = Tensor(shape: _w2.shape, element: 0)
            var dldw1 = Tensor(shape: _w1.shape, element: 0)
            var dldb1 = Tensor(shape: _b1.shape, element: 0)
            var dldb2 = Tensor(shape: _b2.shape, element: 0)
            for i in 0..<a2.cols {
                let dldz2i = a2[b, i] - y[b, i]
                
                let dz2idbi: Float = 1
                dldb2[0, i] = dz2idbi * dldz2i
                
                for j in 0..<a1.cols {
                    let dz2idw2ji = a1[b, j]
                    dldw2[j, i] = dz2idw2ji * dldz2i
                    
                    let dz2ida1j = _w2[j, i]
                    let da1jdz1j: Float = z1[b, j] > 0 ? 1 : 0
                    
                    let dldz1j = da1jdz1j * dz2ida1j * dldz2i
                    let dz1jdbj: Float = 1
                    dldb1[0, j] += dz1jdbj * dldz1j
                    
                    for k in 0..<x.cols {
                        let dz1jdw1kj = x[b, k]
                        dldw1[k, j] += dz1jdw1kj * dldz1j
                    }
                }
            }
            w1grads.append(dldw1)
            w2grads.append(dldw2)
            b1grads.append(dldb1)
            b2grads.append(dldb2)
        }
        let w1grads_mean = w1grads.reduce(Tensor(shape: _w1.shape, element: 0), +) / Float(w1grads.count)
        let w2grads_mean = w2grads.reduce(Tensor(shape: _w2.shape, element: 0), +) / Float(w2grads.count)
        let b1grads_mean = b1grads.reduce(Tensor(shape: _b1.shape, element: 0), +) / Float(b1grads.count)
        let b2grads_mean = b2grads.reduce(Tensor(shape: _b2.shape, element: 0), +) / Float(b2grads.count)

        let beta1: Float = 0.9
        let beta2: Float = 0.999
        let eps: Float = powf(10, -8)
        
        let beta1denom = 1 - powf(beta1, Float(epoch))
        let beta2denom = 1 - powf(beta2, Float(epoch))
        
        _mw1 = beta1 * _mw1 + (1 - beta1) * w1grads_mean
        _vw1 = beta2 * _vw1 + (1 - beta2) * w1grads_mean ** 2
        let mw1_hat = _mw1 / beta1denom
        let vw1_hat = _vw1 / beta2denom
        _w1 = _w1 - learningRate * mw1_hat / (vw1_hat ** 0.5 + Tensor(shape: vw1_hat.shape, element: eps))
        
        _mw2 = beta1 * _mw2 + (1 - beta1) * w2grads_mean
        _vw2 = beta2 * _vw2 + (1 - beta2) * w2grads_mean ** 2
        let mw2_hat = _mw2 / beta1denom
        let vw2_hat = _vw2 / beta2denom
        _w2 = _w2 - learningRate * mw2_hat / (vw2_hat ** 0.5 + Tensor(shape: vw2_hat.shape, element: eps))
        
        _mb1 = beta1 * _mb1 + (1 - beta1) * b1grads_mean
        _vb1 = beta2 * _vb1 + (1 - beta2) * b1grads_mean ** 2
        let mb1_hat = _mb1 / beta1denom
        let vb1_hat = _vb1 / beta2denom
        _b1 = _b1 - learningRate * mb1_hat / (vb1_hat ** 0.5 + Tensor(shape: vb1_hat.shape, element: eps))
        
        _mb2 = beta1 * _mb2 + (1 - beta1) * b2grads_mean
        _vb2 = beta2 * _vb2 + (1 - beta2) * b2grads_mean ** 2
        let mb2_hat = _mb2 / beta1denom
        let vb2_hat = _vb2 / beta2denom
        _b2 = _b2 - learningRate * mb2_hat / (vb2_hat ** 0.5 + Tensor(shape: vb2_hat.shape, element: eps))
        
//        _w1 = _w1 -  learningRate * w1grads_mean
//        _w2 = _w2 -  learningRate * w2grads_mean
//        _b1 = _b1 -  learningRate * b1grads_mean
//        _b2 = _b2 -  learningRate * b2grads_mean
    }
    
    func evaluate(xRaw: [[Float]], yRaw: [Float], numberOfClasses: Int) -> EvaluationResult {
        let x = Tensor(shape: Shape([Dimension(xRaw.count), Dimension(xRaw[0].count)]), elements: xRaw.flatMap { $0 })
        var y = Tensor(shape: Shape([Dimension(xRaw.count)]), elements: yRaw)
        y = y.onehot(numberOfClasses: numberOfClasses)
        let (_, _, _, probs) = forwardPass(x)
        let loss = Tensor.softmaxCrossentropy(probs: probs, labels: y)
        let meanLoss = loss.elements.reduce(0, +) / Float(loss.elements.count)
        
        var predictedClasses: [Float] = []
        for i in 0..<probs.rows {
            var predictedClass = 0
            var maxProb: Float = 0
            for k in 0..<probs.cols {
                if probs[i, k] > maxProb {
                    maxProb = probs[i, k]
                    predictedClass = k
                }
            }
            predictedClasses.append(Float(predictedClass))
        }
        
        var matchCounter = 0
        for (trueClass, predictedClass) in zip(yRaw, predictedClasses) {
            if trueClass == predictedClass {
                matchCounter += 1
            }
        }
        let accuracy = Float(matchCounter) / Float(xRaw.count)
        return (meanLoss, accuracy)
    }
    
    func saveParameters() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let modelDirPath = (documentsPath as NSString).appendingPathComponent("ModelParameters")
        if !FileManager.default.fileExists(atPath: modelDirPath) {
            try! FileManager.default.createDirectory(atPath: modelDirPath, withIntermediateDirectories: false, attributes: nil)
        }
        
        let unitsTensor = Tensor(shape: Shape([1, 2]), elements: [_inputUnits, _l1Units, _l2Units].map(Float.init))
        let tensorsToSave: [Tensor] = [unitsTensor, _w1, _w2, _b1, _b2]
        let filenames: [String] = ["units", "w1", "w2", "b1", "b2"]
        for (tensor, filename) in zip(tensorsToSave, filenames) {
            let filepath = (modelDirPath as NSString).appendingPathComponent("\(filename).csv")
            try! tensor.toCSVString().write(toFile: filepath, atomically: true, encoding: .utf8)
        }
    }
    
//    func predict(xRaw: [[Float]]) -> Tensor {
//        let x = Tensor(shape: Shape([Dimension(xRaw.count), Dimension(xRaw[0].count)]), elements: xRaw.flatMap { $0 })
//        let (_, _, _, probs) = forwardPass(x)
//        return probs
//    }
}

extension Tensor {
    var rows: Int {
        assert(shape.dimensions.count >= 1, "Tensor's shape should be > 1.")
        return shape.dimensions[0].value
    }
    
    var cols: Int {
        assert(shape.dimensions.count >= 2, "Tensor's shape should be > 2.")
        return shape.dimensions[1].value
    }
    
    func toCSVString() -> String {
        var resStr: String = ""
        for i in 0..<rows {
            var rowStr: String = ""
            for k in 0..<cols {
                rowStr.append(String(self[i, k]))
                if k == cols - 1 {
                    if i != rows - 1 {
                        rowStr.append("\n")
                    }
                } else {
                    rowStr.append(",")
                }
            }
            resStr.append(rowStr)
        }
        return resStr
    }
    
    static func from(csvString str: String) -> Tensor {
        var els: [Element] = []
        let rowStrs = str.split(separator: "\n")
        let rowsNum = rowStrs.count
        var colsNum = 0
        for rowStr in rowStrs {
            let colStrs = rowStr.split(separator: ",")
            colsNum = colStrs.count
            for colStr in colStrs {
                let el = Float(String(colStr))!
                els.append(el)
            }
        }
        let tensor = Tensor(shape: Shape([Dimension(rowsNum), Dimension(colsNum)]), elements: els)
        return tensor
    }
    
    static func gaussian(mean: Element, deviation: Element, shape: Shape) -> Tensor {
        let generator = GaussianGenerator()
        var els: [Element] = []
        for _ in 0..<shape.volume() {
            let randomNum = Float(generator.nextGaussian()) * deviation + mean
            els.append(randomNum)
        }
        return Tensor(shape: shape, elements: els)
    }
    
    static func glorot(fanIn: Int, fanOut: Int, shape: Shape) -> Tensor {
        let variance: Float = 2.0 / Float(fanIn + fanOut)
        let deviation = sqrtf(variance)
        return gaussian(mean: 0, deviation: deviation, shape: shape)
    }
    
    func relu() -> Tensor {
        return Tensor(shape: shape, elements: elements.map { $0 > 0 ? $0 : 0 })
    }
    
    func softmax() -> Tensor {
        var softmaxed = Tensor(shape: shape, element: 0)
        for i in 0..<rows {
            var exps: [Float] = []
            var expsSum: Float = 0
            for k in 0..<cols {
                let exp = expf(self[i, k])
                exps.append(exp)
                expsSum += exp
            }
            for k in 0..<cols {
                softmaxed[i, k] = exps[k] / expsSum
            }
        }
        return softmaxed
    }
    
    func transpose() -> Tensor {
        assert(shape.dimensions.count == 2, "Tensor is not a matrix.")
        let rows = shape.dimensions[0].value
        let cols = shape.dimensions[1].value
        var transposedEls: [Element] = []
        for col in 0..<cols {
            for row in 0..<rows {
                transposedEls.append(elements[row * cols + col])
            }
        }
        return Tensor(shape: Shape(shape.dimensions.reversed()), elements: transposedEls)
    }
    
    func onehot(numberOfClasses: Int) -> Tensor {
        var onehotLabels = Tensor(shape: Shape([shape.dimensions[0], Dimension(numberOfClasses)]), element: 0)
        for i in 0..<rows {
            for k in 0..<numberOfClasses {
                onehotLabels[i, k] = self[i] == Float(k) ? 1 : 0
            }
        }
        return onehotLabels
    }
    
    static func softmaxCrossentropy(probs: Tensor, labels: Tensor) -> Tensor {
        var crossentropy = Tensor(shape: Shape([Dimension(probs.rows)]), element: 0)
        for i in 0..<probs.rows {
            for k in 0..<probs.cols {
                guard labels[i, k] == 1 else { continue }
                crossentropy[i] = -logf(probs[i, k])
            }
        }
        return crossentropy
    }
}
