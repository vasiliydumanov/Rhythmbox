//
//  RecordJerkViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import Speech
import AVFoundation
import CoreMotion


class RecordJerkViewController: UIViewController {
    private let _audioEngine = AVAudioEngine()
    private var _recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var _recognitionTask: SFSpeechRecognitionTask?
    private let _speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var _chartVC: ChartViewController!
    
    private var _wasStarted = false
    private var _wasStopped = false
    
    private var _recordingLbl: UILabel!
    private let _jerkName: String

    init(jerkName: String) {
        _jerkName = jerkName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkSpeechRecognitionPermissions()
        setupRecordingLabel()
        setupChartViewController()
    }
    
    private func setupRecordingLabel() {
        _recordingLbl = UILabel().then {
            $0.text = "RECORDING"
            $0.font = UIFont.boldSystemFont(ofSize: 24)
            $0.textColor = UIColor.red.darkerColor(percent: 0.1)
            $0.textAlignment = .center
            $0.isHidden = true
        }
        view.addSubview(_recordingLbl)
        _recordingLbl.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.height.equalTo(100)
            make.top.equalTo(view.snp.topMargin)
        }
    }
    
    private func setupChartViewController() {
        _chartVC = ChartViewController(nibName: nil, bundle: nil)
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
    
    private var _isHighlighting = false
    
    private var _isTrackingJerk = false
    private var _jerkPatienceFrameCounter: Int = 0
    private let kJerkTriggerBoundary: Double = 0.3
    private let kJerkEndPatience: Int = 30
    
    private func checkSpeechRecognitionPermissions() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            autorizeSpeechRecognition()
        case .authorized:
            startMicrophoneRecordingAndRecognition()
        case .denied, .restricted:
            fatalError("Speech recognition permission denied.")
        }
    }
    
    private func autorizeSpeechRecognition() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            switch status {
            case .authorized:
                self?.startMicrophoneRecordingAndRecognition()
            default:
                fatalError("Speech recognition permission denied.")
            }
        }
    }
    
    private func startMicrophoneRecordingAndRecognition() {
        _recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let node = _audioEngine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?._recognitionRequest?.append(buffer)
        }
        
        _audioEngine.prepare()
        try! _audioEngine.start()
        
        _recognitionTask = _speechRecognizer?.recognitionTask(with: _recognitionRequest!, resultHandler: { [unowned self] result, error in
            guard let result = result else { return }
            let resStr = result.bestTranscription.formattedString.lowercased()
            print(resStr)
            if !self._wasStarted && resStr.contains("start") {
                self.startAction()
            } else if !self._wasStopped && resStr.contains("stop") {
                self.stopAction()
            }
        })
    }
    
    func stopMicrophoneRecordingAndRecognition() {
        guard _audioEngine.isRunning else { return }
        _recognitionRequest?.endAudio()
        _recognitionTask?.cancel()
        _audioEngine.stop()
        _audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func startAction() {
        _wasStarted = true
        stopMicrophoneRecordingAndRecognition()
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.async { [weak self] in
            self?._recordingLbl.isHidden = false
        }
        DispatchQueue.global().async { [weak self] in
            sleep(1)
            self?.startMicrophoneRecordingAndRecognition()
        }
    }
    
    private func stopAction() {
        _wasStopped = true
        stopMicrophoneRecordingAndRecognition()
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        _chartVC.stop()
        DispatchQueue.main.async { [weak self] in
            self?._recordingLbl.isHidden = true
        }
        saveJerks()
    }
    
    private func saveJerks() {
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let jerksDirPath = (documentsPath as NSString).appendingPathComponent("Jerks")
        if !fm.fileExists(atPath: jerksDirPath) {
            try! fm.createDirectory(atPath: jerksDirPath, withIntermediateDirectories: false, attributes: [:])
        }
        let jerkClassPath = (jerksDirPath as NSString).appendingPathComponent("\(_jerkName).csv")
        if fm.fileExists(atPath: jerkClassPath) {
            try! fm.removeItem(atPath: jerkClassPath)
        }
        fm.createFile(atPath: jerkClassPath, contents: nil, attributes: nil)
        
        let fileHandle = FileHandle(forWritingAtPath: jerkClassPath)!
        for jerk in _chartVC.jerks {
            let jerkStr = jerk.values.map(String.init).joined(separator: ",") + "\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(jerkStr.data(using: .utf8)!)
        }
    }
}
