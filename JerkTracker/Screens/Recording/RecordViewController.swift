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
import swix

enum RecordingMode {
    case add, create
}

class RecordViewController: ViewController {
    private let kInfo = "Say \"Start\" to begin recording. You should feel phone vibrating which means that recording has began. Tap or shake the phone with chosen rhythmic pattern. Note that by default pattern duration cannot exceed 2s (120 motion data readings). You will also feel phone vibrating after pattern has been recorded. Continue tapping the phone with the same rythmic pattern >= 20 times. 20 is big enough for default neural net to reach reasonably high accuracy on test test, though the rule of thumb here is: the more, the better. YMMV for more complex rhythmic patterns. When you are ready to stop recording, say \"Stop\"."
    
    private let _audioEngine = AVAudioEngine()
    private var _recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var _recognitionTask: SFSpeechRecognitionTask?
    private let _speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var _chartView: ChartView!
    private var _recordedRythmsCounter: Int = 0
    private var _cntrLbl: UILabel!
    
    private var _newRhythmRecordingBeganOnce = false
    private var _isRecording = false
    private var _wasStarted = false
    private var _wasStopped = false
    
    private let _rhythmType: RhythmType
    private let _recordingMode: RecordingMode
    
    private var _rhythms: [Rhythm] = []
    private var _tracker: RhythmTracker!

    init(rhythmType: RhythmType, recordingMode: RecordingMode) {
        _rhythmType = rhythmType
        _recordingMode = recordingMode
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        title = "Record"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.default.cardsBody
        checkSpeechRecognitionPermissions()
        setupNavBar()
        setupChart()
        setupCounterLabel()
        setupRhythmTracker()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard !_wasStopped else { return }
        stopAction(onDisappear: true)
    }
    
    private func setupNavBar() {
        let infoView = UIButton(type: .infoLight)
        infoView.addTarget(self, action: #selector(infoAction), for: .touchUpInside)
        let infoItem = UIBarButtonItem(customView: infoView)
        navigationItem.rightBarButtonItem = infoItem
    }
    
    private func setupChart() {
        _chartView = ChartView(frame: view.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.yRange = (0...5)
            $0.chartColor = .white
            $0.highlightColor = UIColor.white.withAlphaComponent(0.2)
            $0.backgroundColor = .clear
            $0.axesColor = .clear
        }
        view.addSubview(_chartView)
        _chartView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40)
            make.top.equalToSuperview()
        }
    }
    
    private func setupCounterLabel() {
        let cntrRadius: CGFloat = 60
        let cntrView = UIView().then {
            $0.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            $0.layer.cornerRadius = cntrRadius / 2
        }
        view.addSubview(cntrView)
        cntrView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(40)
            make.width.equalTo(cntrRadius)
            make.height.equalTo(cntrRadius)
        }
        
        _cntrLbl = UILabel().then {
            $0.text = "0"
            $0.textColor = .white
            $0.font = UIFont.boldSystemFont(ofSize: 32)
        }
        cntrView.addSubview(_cntrLbl)
        _cntrLbl.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    private func incrementRhythmsCounter() {
        _recordedRythmsCounter += 1
        _cntrLbl.text = String(_recordedRythmsCounter)
    }
    
    private func setupRhythmTracker() {
        _tracker = RhythmTracker().then {
            $0.delegate = self
        }
        _tracker.start()
    }
    
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
        let recordingFormat = node.inputFormat(forBus: 0)
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
        _audioEngine.inputNode.removeTap(onBus: 0)
        _audioEngine.inputNode.reset()
        _audioEngine.stop()
        _recognitionRequest?.endAudio()
        _recognitionTask?.cancel()
    }
    
    private func startAction() {
        _isRecording = true
        _wasStarted = true
        stopMicrophoneRecordingAndRecognition()
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.view.backgroundColor = Theme.default.record
            }
        }
        DispatchQueue.global().async { [weak self] in
            sleep(1)
            self?.startMicrophoneRecordingAndRecognition()
        }
    }
    
    private func stopAction(onDisappear: Bool = false) {
        _isRecording = false
        _wasStopped = true
        stopMicrophoneRecordingAndRecognition()
        if !onDisappear {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.2) {
                    self?.view.backgroundColor = Theme.default.cardsBody
                }
            }
            askSaveRhythms()
        }
    }
    
    private func askSaveRhythms() {
        let alert = UIAlertController(title: nil, message: "Save recorded rhythms?", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
                self?.saveRhythms()
                self?.navigationController?.popViewController(animated: true)
            }
        )
        alert.addAction(
            UIAlertAction(title: "No", style: .destructive) { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }
        )
        present(alert, animated: true)
    }
    
    private func saveRhythms() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: RhythmType.rootDir) {
            try! fm.createDirectory(atPath: RhythmType.rootDir, withIntermediateDirectories: true, attributes: [:])
        }
        if case .create = _recordingMode {
            fm.createFile(atPath: _rhythmType.file, contents: nil, attributes: nil)
        }
        
        let fileHandle = FileHandle(forWritingAtPath: _rhythmType.file)!
        if case .add = _recordingMode {
            fileHandle.seekToEndOfFile()
        }
        for rhythm in _rhythms {
            let rhythmStr = rhythm.data.map(String.init).joined(separator: ",") + "\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(rhythmStr.data(using: .utf8)!)
        }
    }
    
    @objc private func infoAction() {
        let alert = UIAlertController(title: nil, message: kInfo, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
}

extension RecordViewController : RhythmTrackerDelegate {
    func rhythmTrackingBegan() {
        _chartView.startHighlighting()
        guard _isRecording else { return }
        _newRhythmRecordingBeganOnce = true
    }
    
    func rhythmTrackingEnded(_ rhythm: Rhythm) {
        _chartView.stopHighlighting()
        guard _isRecording && _newRhythmRecordingBeganOnce else { return }
        _rhythms.append(rhythm)
        DispatchQueue.main.async { [weak self] in
            self?.incrementRhythmsCounter()
        }
    }
    
    func gotJerkData(_ jerk: Double) {
        DispatchQueue.main.async { [weak self] in
            self?._chartView.add(yCoord: jerk)
        }
    }
}
