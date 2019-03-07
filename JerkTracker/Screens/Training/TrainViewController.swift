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


final class TrainViewController : ViewController {
    private let kInfo = "Tap \"Train\" to train model on existing samples. Observe training progress. Don't forget to \"Save\" trained weights after the training is over. Good Luck! 😉"
    
    private let _computationQueue = DispatchQueue(label: "compute_queue")
    private var _repeatTrainingItem: UIBarButtonItem!
    private var _tasButton: UIButton!
    private var _logTextView: UITextView!
    private var _hintLbl: UILabel!
    
    private var _nn: RhythmNet!
    
    private var _wasTrained = false
    private var _wasSaved = false
    
    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        title = "Train"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        _nn = RhythmNet()
        setupNavBar()
        setupTrainAndSaveButton()
        setupTextView()
        setupHint()
    }
    
    private func setupNavBar() {
        let closeItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeAction))
        navigationItem.leftBarButtonItem = closeItem
        
        let infoView = UIButton(type: .infoLight)
        infoView.addTarget(self, action: #selector(infoAction), for: .touchUpInside)
        let infoItem = UIBarButtonItem(customView: infoView)
        
        _repeatTrainingItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(repeatTrainingAction)).then {
            $0.isEnabled = false
        }
        
        navigationItem.rightBarButtonItems = [infoItem, _repeatTrainingItem]
    }
    
    private func setupTrainAndSaveButton() {
        _tasButton = UIButton(type: .custom).then {
            $0.setBackgroundImage(UIImage(color: Theme.default.cardsHeader), for: .normal)
            $0.setBackgroundImage(UIImage(color: UIColor.darkGray), for: .disabled)
            $0.setTitleColor(.white, for: .normal)
            $0.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            $0.setTitle("Start training", for: .normal)
        }
        _tasButton.addTarget(self, action: #selector(trainOrSaveAction), for: .touchUpInside)
        view.addSubview(_tasButton)
        _tasButton.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(60)
        }
    }
    
    private func setupTextView() {
        _logTextView = UITextView().then {
            $0.backgroundColor = .clear
            $0.textColor = .white
            $0.isEditable = false
            $0.isSelectable = false
            $0.text = ""
            $0.font = UIFont.systemFont(ofSize: 16)
        }
        view.addSubview(_logTextView)
        _logTextView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalTo(_tasButton.snp.top)
        }
    }
    
    private func setupHint() {
        _hintLbl = UILabel().then {
            $0.text = "Logs will appear here"
            $0.textColor = UIColor.lightGray
            $0.font = UIFont.boldSystemFont(ofSize: 16)
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }
        view.addSubview(_hintLbl)
        _hintLbl.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(_logTextView)
        }
    }
    
    private func loadData() -> (rhythms: [Rhythm], labels: [Int]) {
        var rhythmsData: [[Double]] = []
        var labels: [Int] = []
        
        for rt in RhythmType.allCases {
            let rhythmsStr = try! String(contentsOfFile: rt.file, encoding: .utf8)
            for rhythmStr in rhythmsStr.split(separator: "\n") {
                let rhythmData = rhythmStr.split(separator: ",").map { Double($0)! }
                rhythmsData.append(rhythmData)
                labels.append(rt.rawValue)
            }
        }
        
        for i in 0..<rhythmsData.count {
            let padding: [Double] = Array(repeating: 0, count: RhythmNet.kInputSize - rhythmsData[i].count)
            rhythmsData[i] = padding + rhythmsData[i]
        }

        let rhythms = rhythmsData.map { data in Rhythm().then { $0.data = data } }
        return (rhythms, labels)
    }
    
    private func trainModel(nEpochs: Int = 10, batchSize: Int = 16, valPct: Float = 0.1) {
        _wasTrained = false
        _wasSaved = false
        _logTextView.text = ""
        _tasButton.do {
            $0.isEnabled = false
            $0.setTitle("Training...", for: .normal)
        }
        _hintLbl.isHidden = true
        _computationQueue.async { [weak self] in
            let (rhythms, labels) = self!.loadData()
            self?._nn.train(rhythms: rhythms, labels: labels, onEpochEnd: { epoch, log in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        self._tasButton.setTitle("Training (\(epoch)/\(RhythmNet.kNEpochs))", for: .normal)
                    }
                    var resLogStr = "\(log[.epochLogStr] as! String)\n\n"
                    if let esLogStr = log[.esLogStr] as? String {
                        resLogStr += "\(esLogStr)\n\n"
                    }
                    self._logTextView.text += resLogStr
                }
            })
            
            DispatchQueue.main.async {
                self?._wasTrained = true
                self?._tasButton.do {
                    $0.isEnabled = true
                    $0.setTitle("Save", for: .normal)
                }
                self?._repeatTrainingItem.isEnabled = true
            }
        }
    }
    
    @objc private func trainOrSaveAction() {
        if !_wasTrained {
            trainModel()
        } else {
            saveParameters()
        }
    }
    
    private func saveParameters() {
        _nn.saveParameters()
        _wasSaved = true
        
        let alert = UIAlertController(title: nil, message: "Parameters saved", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func closeAction() {
        guard _wasTrained && !_wasSaved else {
            _nn?.cancelTraining()
            dismiss(animated: true)
            return
        }
        let alert = UIAlertController(title: nil, message: "Close without saving?", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func infoAction() {
        let alert = UIAlertController(title: nil, message: kInfo, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func repeatTrainingAction() {
        trainModel()
    }
}
