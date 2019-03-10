//
//  PlayerViewController.swift
//  Rhythmbox
//
//  Created by Vasiliy Dumanov on 3/4/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerViewController: ViewController {
    private let kInfo = "This is the screen for experimenting with model inference abilities. The app is not able to record motion data in background due to iOS system limitations, therefore make sure that the phone is not locked. When you are ready, tap or shake the phone with the same rhythmic patterns you used for samples recording to invoke 1 of 3 actions: \"Play/Pause\", \"Next\" or \"Previous\". Have fun!"
    
    private typealias PlayerData = (trackName: String, player: AVAudioPlayer)
    
    private var _pocketModeView: UIStackView!
    private var _controlsStack: UIStackView!
    private var _trackNameLbl: UILabel!
    private var _playPauseBtn: UIButton!
    private var _playersData: [PlayerData] = []
    private var _currentTrackId: Int = 0
    private var _activePlayer: AVAudioPlayer? = nil
    private var _isPlaying: Bool = false
    private var _tracker: RhythmTracker!
    private var _net: RhythmNet!
    
    private var _isPocketModeEnabled: Bool = false
    private var _isViewVisible = false

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Player"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBar()
        try! setupPlayers()
        setupPocketMode()
        setupPlaybackControls()
        setupTrackInfo()
        setupProximityMonitoring()
        setupRhythmRecognition()
    }
    
    private func updateTrackingState() {
        let trackingAllowed = (!_isPocketModeEnabled || UIDevice.current.proximityState) && _isViewVisible
        trackingAllowed ? _tracker.start() : _tracker.stop()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        _isViewVisible = true
        updateTrackingState()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        _isViewVisible = false
        updateTrackingState()
        if _isPlaying {
            playPauseAction()
        }
    }
    
    private func setupNavBar() {
        let infoView = UIButton(type: .infoLight)
        infoView.addTarget(self, action: #selector(infoAction), for: .touchUpInside)
        let infoItem = UIBarButtonItem(customView: infoView)
        navigationItem.rightBarButtonItem = infoItem
        
        navigationController?.navigationBar.shadowImage = UIImage()
    }
    
    private func setupPocketMode() {
        let pmHeight: CGFloat = 60
        _pocketModeView = UIStackView().then {
            $0.axis = .horizontal
            $0.spacing = 20
            $0.alignment = .center
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        }
        view.addSubview(_pocketModeView)
        _pocketModeView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
            make.height.equalTo(pmHeight)
        }
        
        let pocketViewBg = UIView(frame: _pocketModeView.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.backgroundColor = Theme.default.barsAndHeaders
            $0.layer.cornerRadius = pmHeight / 2
        }
        _pocketModeView.addSubview(pocketViewBg)
        
        let lbl = UILabel().then {
            $0.textColor = .white
            $0.font = UIFont.systemFont(ofSize: 18)
            $0.text = "Pocket Mode"
        }
        _pocketModeView.addArrangedSubview(lbl)
        
        let swtch = UISwitch().then {
            $0.onTintColor = Theme.default.cardsHeader
            $0.addTarget(self, action: #selector(pocketModeToggled), for: .touchUpInside)
        }
        _pocketModeView.addArrangedSubview(swtch)
    }
    
    @objc private func pocketModeToggled() {
        _isPocketModeEnabled.toggle()
        updateTrackingState()
    }
    
    private func setupPlaybackControls() {
        let stackHeight: CGFloat = 60
        _controlsStack = UIStackView().then {
            $0.axis = .horizontal
            $0.alignment = .center
            $0.distribution = .equalSpacing
            $0.isLayoutMarginsRelativeArrangement = true
            $0.layoutMargins = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        }
        view.addSubview(_controlsStack)
        _controlsStack.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(stackHeight)
        }
        
        let controlsBg = UIView(frame: _controlsStack.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.backgroundColor = Theme.default.cardsBody
        }
        _controlsStack.addSubview(controlsBg)
        
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
            _controlsStack.addArrangedSubview(btn)
            btn.snp.makeConstraints { make in
                make.size.equalTo(buttonSize)
            }
            buttons.append(btn)
        }
        _playPauseBtn = buttons[1]
    }
    
    private func setupTrackInfo() {
        let trackInfoContainer = UIView()
        view.addSubview(trackInfoContainer)
        trackInfoContainer.snp.makeConstraints { make in
            make.top.equalTo(_pocketModeView.snp.bottom)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalTo(_controlsStack.snp.top)
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
        guard _isPocketModeEnabled else { return }
        updateTrackingState()
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
    
    @objc private func infoAction() {
        let alert = UIAlertController(title: nil, message: kInfo, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true)
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
