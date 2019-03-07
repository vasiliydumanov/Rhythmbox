//
//  PlayerViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/4/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerViewController: ViewController {
    private typealias PlayerData = (trackName: String, player: AVAudioPlayer)
    
    private var _trackNameLbl: UILabel!
    private var _playPauseBtn: UIButton!
    private var _playersData: [PlayerData] = []
    private var _currentTrackId: Int = 0
    private var _activePlayer: AVAudioPlayer? = nil
    private var _isPlaying: Bool = false
    private var _tracker: RhythmTracker!
    private var _net: RhythmNet!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Player"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        try! setupPlayers()
        setupUI()
        setupProximityMonitoring()
        setupRhythmRecognition()
    }
    
    private func setupUI() {
        let stackHeight: CGFloat = 60
        let controlsStack = UIStackView().then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.distribution = .equalSpacing
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        }
        view.addSubview(controlsStack)
        controlsStack.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(stackHeight)
        }
        
        let controlsBg = UIView(frame: controlsStack.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.backgroundColor = Theme.default.cardsBody
        }
        controlsStack.addSubview(controlsBg)
        
        typealias ButtonData = (icon: String, selector: Selector)
        let buttonsData: [ButtonData] = [
            ("control_prev", #selector(prevAction)),
            ("control_play", #selector(playPauseAction)),
            ("control_next", #selector(nextAction))
        ]
        var buttons: [UIButton] = []
        let buttonSize = CGSize(width: 40, height: 40)
        for bd in buttonsData {
            let img = UIImage(named: bd.icon)!
            let btn = UIButton(type: .system).then {
                $0.tintColor = Theme.default.cardsHeader
                $0.imageView?.contentMode = .scaleAspectFit
                $0.contentHorizontalAlignment = .fill
                $0.contentVerticalAlignment = .fill
                $0.setImage(img, for: .normal)
                $0.imageEdgeInsets = .zero
                $0.addTarget(self, action: bd.selector, for: .touchUpInside)
            }
            controlsStack.addArrangedSubview(btn)
            btn.snp.makeConstraints { make in
                make.size.equalTo(buttonSize)
            }
            buttons.append(btn)
        }
        _playPauseBtn = buttons[1]
        
        let trackInfoContainer = UIView()
        view.addSubview(trackInfoContainer)
        trackInfoContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalTo(controlsStack.snp.top)
        }
        
        _trackNameLbl = UILabel().then {
            $0.font = .boldSystemFont(ofSize: 28)
            $0.textColor = .white
            $0.text = _currentTrack.trackName
            $0.numberOfLines = 0
            $0.textAlignment = .center
        }
        trackInfoContainer.addSubview(_trackNameLbl)
        _trackNameLbl.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
    }
    
    private func setupProximityMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(proximityStateChanged), name: UIDevice.proximityStateDidChangeNotification, object: nil)
    }
    
    @objc private func proximityStateChanged() {
        let isClose = UIDevice.current.proximityState
        isClose ? _tracker.start() : _tracker.stop()
    }
    
    private func setupRhythmRecognition() {
        _tracker = RhythmTracker().then {
            $0.delegate = self
        }
        _net = RhythmNet()
        _net.restoreParameters()
        NotificationCenter.default.addObserver(self, selector: #selector(rhythmNetParamsUpdated), name: .rhythmNetParamsUpdated, object: nil)
    }
    
    @objc private func rhythmNetParamsUpdated() {
        _net.restoreParameters()
    }
    
    private func setupPlayers() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        let tracksPath = (Bundle.main.resourcePath! as NSString).appendingPathComponent("Music")
        let tracks = try FileManager.default.contentsOfDirectory(atPath: tracksPath)
        for track in tracks {
            let trackName = String(track.split(separator: ".").first!).replacingOccurrences(of: "_", with: " ")
            let trackPath = (tracksPath as NSString).appendingPathComponent(track)
            let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: trackPath), fileTypeHint: "mp3").then {
                $0.numberOfLoops = -1
            }
            _playersData.append((trackName, player))
        }
        _activePlayer = _currentTrack.player
    }
    
    private var _currentTrack: PlayerData {
        return _playersData[_currentTrackId]
    }
    
    private func nextTrack() -> PlayerData {
        if _currentTrackId == _playersData.count - 1 {
            _currentTrackId = -1
        }
        _currentTrackId += 1
        return _playersData[_currentTrackId]
    }
    
    private func prevTrack() -> PlayerData {
        if _currentTrackId == 0 {
            _currentTrackId = _playersData.count
        }
        _currentTrackId -= 1
        return _playersData[_currentTrackId]
    }
    
    @objc private func playPauseAction() {
        _isPlaying.toggle()
        if _isPlaying {
            _activePlayer?.play()
            _playPauseBtn.setImage(UIImage(named: "control_pause"), for: .normal)
        } else {
            _activePlayer?.pause()
            _playPauseBtn.setImage(UIImage(named: "control_play"), for: .normal)
        }
    }
    
    @objc private func nextAction() {
        set(track: nextTrack())
    }
    
    @objc private func prevAction() {
        set(track: prevTrack())
    }
    
    private func set(track: PlayerData) {
        _activePlayer?.do {
            $0.stop()
            $0.currentTime = 0
        }
        _activePlayer = track.player
        _trackNameLbl.text = track.trackName
        if _isPlaying {
            _activePlayer?.play()
        }
    }

}

extension PlayerViewController : RhythmTrackerDelegate {
    func rhythmTrackingEnded(_ rhythm: Rhythm) {
        let prediction = _net.predict(rhythm: rhythm)
        let predictedRhythmType = RhythmType(rawValue: prediction.cls)!
        print(predictedRhythmType.displayedName)
        DispatchQueue.main.async { [weak self] in
            switch predictedRhythmType {
            case .playPause:
                self?.playPauseAction()
            case .next:
                self?.nextAction()
            case .prev:
                self?.prevAction()
            case .noise:
                break
            }
        }
    }
}
