//
//  AppDelegate.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import TensorSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        resaveJerks()
//        debugNN()
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootVC = UINavigationController(rootViewController: MainViewController(nibName: nil, bundle: nil))
//        window?.rootViewController = rootVC
        window?.rootViewController = RecordJerkViewController(jerkName: "three-2")
//        window?.rootViewController = TrainViewController(nibName: nil, bundle: nil)
        window?.makeKeyAndVisible()
        return true
    }
    
    private func resaveJerks() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let jerksThreeBundlePath = Bundle.main.path(forResource: "three", ofType: "csv")!
        let jerksDirPath = (documentsPath as NSString).appendingPathComponent("Jerks")
        let jerksThreePath = (jerksDirPath as NSString).appendingPathComponent("three.csv")
        let jerkThreeData = try! String(contentsOfFile: jerksThreeBundlePath)
        try! jerkThreeData.write(toFile: jerksThreePath, atomically: true, encoding: .utf8)
    }
    
    private func debugNN() {
        let fileNames = ["w1", "w2", "x", "y"]
        let shapes = [Shape([2, 3]), Shape([3, 2]), Shape([1, 2]), Shape([1])]
        var weights: [Tensor] = []
        var x: [[Float]] = []
        var y: [Float] = []
        for (idx, (name, shape)) in zip(fileNames, shapes).enumerated() {
            let filePath = Bundle.main.path(forResource: name, ofType: "csv")!
            let fileContents = try! String(contentsOfFile: filePath, encoding: .utf8)
            let elements = fileContents.split(separator: "\n").map { Float($0)! }
            if idx < 2 {
                weights.append(Tensor(shape: shape, elements: elements))
            } else if idx == 2 {
                x = [elements]
            } else {
                y = elements
            }
        }
        
        let nn = SimpleNeuralNet(weights)
//        nn.trainBatch(xRaw: x, yRaw: y, xValRaw: [], yValRaw: [], numberOfClasses: 2)
//        nn.forwardPassAndBackprop(x: tensors[2], y: yOnehot)
//        let (z1, a1, z2, a2) = nn.forwardPass(tensors[2])
    }

}

