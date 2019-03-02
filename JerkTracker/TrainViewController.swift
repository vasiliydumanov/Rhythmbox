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
    
    private var _nn: RhythmNet!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        _nn = RhythmNet()
        _ = _nn.restoreParameters()
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
    
    private func loadData() -> (rhythms: [Rhythm], labels: [String]) {
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let rhythmsDirPath = (documentsPath as NSString).appendingPathComponent("Jerks")
        let rhythmsFiles = try! fm.contentsOfDirectory(atPath: rhythmsDirPath)
        
        var rhythmsData: [[Double]] = []
        var labels: [String] = []
        
        for rhythmsFile in rhythmsFiles {
            let rhythmsStr = try! String(contentsOfFile: (rhythmsDirPath as NSString).appendingPathComponent(rhythmsFile), encoding: .utf8)
            let rhythmName = String(rhythmsFile.split(separator: ".").first!)
            for rhythmStr in rhythmsStr.split(separator: "\n") {
                let rhythmData = rhythmStr.split(separator: ",").map { Double($0)! }
                rhythmsData.append(rhythmData)
                labels.append(rhythmName)
            }
        }
        
        for i in 0..<rhythmsData.count {
            let padding: [Double] = Array(repeating: 0, count: RhythmNet.kInputSize - rhythmsData[i].count)
            rhythmsData[i] = padding + rhythmsData[i]
        }

        let rhythms = rhythmsData.map { data in Rhythm().then { $0.values = data } }
        return (rhythms, labels)
    }
    
    private func trainModel(nEpochs: Int = 10, batchSize: Int = 16, valPct: Float = 0.1) {
        _computeItem = DispatchWorkItem { [unowned self] in
            let (rhythms, labels) = self.loadData()
            self._nn.train(rhythms: rhythms, labels: labels)
            
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
