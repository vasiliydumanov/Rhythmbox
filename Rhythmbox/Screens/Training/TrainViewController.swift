//
//  TrainViewController.swift
//  Rhythmbox
//
//  Created by Vasiliy Dumanov on 2/21/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIKit


final class TrainViewController : ViewController {
    private let kInfo = "Tap \"Train\" to train model on existing samples. Observe training progress on \"Charts\" and \"Logs\" tabs. You can always \"Stop\" training if you feel comfortable with achieved accuracy / loss metrics' values. Note that these metrics are not guaranteed to converge even to reasonably good values if you change default samples. In this case you may need to tweak model training parameters or even change its architecture. Also keep in mind that training process can sometimes be unstable between runs, so you can always repeat training by tapping repeat (curved arrow) button, Don't forget to \"Save\" new weights after the training is over. Good Luck! 😉"
    
    private let _computationQueue = DispatchQueue(label: "compute_queue")
    private var _repeatTrainingItem: UIBarButtonItem!
    private var _multiButton: UIButton!
    
    private var _nn: RhythmNet!
    
    private var _isTraining = false
    private var _wasTrained = false
    private var _wasSaved = false
    
    private var _slider: UIView!
    private var _tabBtns: [UIButton] = []
    private var _childControllers: [TrainTabViewController] = []
    
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
        setupMultiButton()
        setupTabs()
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
        
        navigationController?.navigationBar.do {
            $0.shadowImage = UIImage()
        }
    }
    
    private func setupMultiButton() {
        _multiButton = UIButton(type: .custom).then {
            $0.setBackgroundImage(UIImage(color: Theme.default.cardsHeader), for: .normal)
            $0.setBackgroundImage(UIImage(color: UIColor("#c62828")), for: .selected)
            $0.setTitleColor(.white, for: .normal)
            $0.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            $0.setTitle("Start training", for: .normal)
        }
        _multiButton.addTarget(self, action: #selector(multiAction), for: .touchUpInside)
        view.addSubview(_multiButton)
        _multiButton.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(60)
        }
    }
    
    private func setupTabs() {
        let tabsContainer = UIStackView().then {
            $0.axis = .horizontal
            $0.distribution = .fillEqually
        }
        view.addSubview(tabsContainer)
        tabsContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(40)
        }
        
        let tabNames: [String] = ["Charts", "Logs"]
        for (idx, tn) in tabNames.enumerated() {
            let btn = UIButton(type: .custom).then {
                $0.tag = idx
                $0.setTitle(tn, for: .normal)
                $0.setTitleColor(.white, for: .normal)
                $0.backgroundColor = Theme.default.barsAndHeaders
                $0.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
                $0.addTarget(self, action: #selector(switchTabs(_:)), for: .touchUpInside)
            }
            tabsContainer.addArrangedSubview(btn)
            _tabBtns.append(btn)
        }
        
        _slider = UIView().then {
            $0.backgroundColor = Theme.default.cardsBody
        }
        tabsContainer.addSubview(_slider)

        _childControllers = [
            TrainChartsViewController(),
            TrainLogsViewController()
        ]
        let childContainer = UIView()
        view.addSubview(childContainer)
        childContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalTo(tabsContainer.snp.bottom).offset(1)
            make.bottom.equalTo(_multiButton.snp.top)
        }
        
        for cc in _childControllers {
            addChild(cc)
            cc.view.frame = childContainer.bounds
//            cc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            childContainer.addSubview(cc.view)
            cc.didMove(toParent: self)
        }
        switchTabs(_tabBtns[0])
    }
    
    @objc private func switchTabs(_ btn: UIButton) {
        for (idx, cc) in _childControllers.enumerated() {
            cc.view.isHidden = idx != btn.tag
        }
        _slider.snp.remakeConstraints { make in
            make.width.equalTo(UIScreen.main.bounds.width / 2)
            make.height.equalTo(2)
            make.bottom.equalToSuperview()
            make.centerX.equalTo(btn)
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
        _childControllers.forEach { $0.onTrainBegan() }
        _multiButton.isSelected = true
        _repeatTrainingItem.isEnabled = false
        _computationQueue.async { [weak self] in
            let (rhythms, labels) = self!.loadData()
            self?._isTraining = true
            self?._nn.reset()
            self?._nn.train(rhythms: rhythms, labels: labels, onEpochEnd: { epoch, log in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        self._multiButton.setTitle("Stop (Training (\(epoch)/\(RhythmNet.kNEpochs)))", for: .normal)
                    }
                    self._childControllers.forEach { $0.onEpochEnd(epoch: epoch, log: log) }
                }
            })
            
            self?._isTraining = false
            self?._wasTrained = true
            DispatchQueue.main.async {
                self?._repeatTrainingItem.isEnabled = true
                self?._childControllers.forEach { $0.onTrainEnded() }
                self?._multiButton.do {
                    $0.isSelected = false
                    $0.setTitle("Save", for: .normal)
                }
            }
        }
    }
    
    @objc private func multiAction() {
        if _isTraining {
            stopTraining()
        } else if !_wasTrained {
            trainModel()
        } else {
            saveParameters()
        }
    }
    
    private func stopTraining() {
        _nn?.cancelTraining()
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
            DispatchQueue.global().async { [weak self] in
                self?._nn?.cancelTraining()
            }
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
