//
//  DemoViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML

class DemoViewController: UIViewController, ChartViewControllerDelegate {
    private var _chartVC: ChartViewController!
    private lazy var _synthesizer = AVSpeechSynthesizer()
    
    private lazy var _classLabels: [String] = {
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let jerksDirPath = (documentsPath as NSString).appendingPathComponent("Jerks")
        let jerksFiles = try! fm.contentsOfDirectory(atPath: jerksDirPath)
        let jerksClasses = jerksFiles.map { $0.components(separatedBy: ".").first! }
        return jerksClasses
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupChartViewController()
    }
    
    private func setupChartViewController() {
        _chartVC = ChartViewController(nibName: nil, bundle: nil).then {
            $0.delegate = self
        }
        addChild(_chartVC)
        _chartVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(_chartVC.view)
        _chartVC.view.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40)
            make.top.equalTo(view.snp.topMargin).offset(100)
        }
        _chartVC.didMove(toParent: self)
    }
    
    private func speak(_ txt: String) {
        let ut = AVSpeechUtterance(string: txt).then {
            $0.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        _synthesizer.speak(ut)
    }
    
    private func predictOnDevice(_ jerk: Rhythm) {
        let nn = SimpleNeuralNet()
        var jerkValues = jerk.values.map(Float.init)
        guard jerkValues.count <= nn.inputUnits else { return }
        jerkValues = Array<Float>(repeating: 0, count: nn.inputUnits - jerkValues.count) + jerkValues
        let preds = nn.predict(xRaw: [jerkValues]).first!
        var maxId = 0
        var maxPred: Float = 0
        for (idx, pred) in preds.enumerated() {
            if pred > maxPred {
                maxPred = pred
                maxId = idx
            }
        }
        
        let clsLbl = _classLabels[maxId]
        print(clsLbl)
        speak(clsLbl)
    }
    
    func newJerkRecorded(_ jerk: Rhythm) {
        predictOnDevice(jerk)
    }
}
