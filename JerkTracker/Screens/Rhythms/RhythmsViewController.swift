//
//  RhythmsViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/4/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import swix
import Zip

enum RhythmType : Int, CaseIterable {
    static let rootDir: String = {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return (documentsPath as NSString).appendingPathComponent("Rhythms")
    }()
    
    case playPause
    case next
    case prev
    case noise
    
    var displayedName: String {
        switch self {
        case .playPause:
            return "Play/Pause"
        case .next:
            return "Next"
        case .prev:
            return "Previous"
        case .noise:
            return "Noise"
        }
    }
    
    var file: String {
        let rhythmFileName: String
        switch self {
        case .playPause:
            rhythmFileName = "PlayPause"
        case .next:
            rhythmFileName = "Next"
        case .prev:
            rhythmFileName = "Prev"
        case .noise:
            rhythmFileName = "Noise"
        }
        return (RhythmType.rootDir as NSString).appendingPathComponent(rhythmFileName)
    }
}

class RhythmsViewController : ViewController {
    private let kInfo = "Here you can create brand new samples of rhythmic patterns for a given action (Play/Pause, Next, Previous) or add new to existing ones (see \"Record\" screen help for more on this). Please note that all samples for any given action must represent the same rhythmic pattern. Note that neural network will not be able to recorgnize your custom samples before you train it (\"Options\" -> \"Train\")."
    
    private var _rhythmsListCV: UICollectionView!
    fileprivate var _nSamplesList: [Int]!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Rhythms"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        try! moveDefaultRhythmsToAppDocumentsDirIfNeeded()
        try! RhythmNet.restoreDefaultParamsIfNeeded()
        setupNavBar()
        setupRhythmsList()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }
    
    private func moveDefaultRhythmsToAppDocumentsDirIfNeeded() throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: RhythmType.rootDir) else { return }
        try fm.createDirectory(atPath: RhythmType.rootDir, withIntermediateDirectories: false, attributes: nil)
        let defaultRhythmsPath = (Bundle.main.resourcePath! as NSString).appendingPathComponent("DefaultRhythms")
        let defaultRhythmsFiles = try fm.contentsOfDirectory(atPath: defaultRhythmsPath)
        for rf in defaultRhythmsFiles {
            let fromPath = (defaultRhythmsPath as NSString).appendingPathComponent(rf)
            let toPath = (RhythmType.rootDir as NSString).appendingPathComponent(rf)
            try fm.copyItem(atPath: fromPath, toPath: toPath)
        }
    }
    
    private func resetToDefault(for rt: RhythmType) throws {
        let defaultRhythmsPath = (Bundle.main.resourcePath! as NSString).appendingPathComponent("DefaultRhythms")
        let rtFileName = String(rt.file.split(separator: "/").last!)
        let defaultRhythmFilePath = (defaultRhythmsPath as NSString).appendingPathComponent(rtFileName)
        let fm = FileManager.default
        try fm.removeItem(atPath: rt.file)
        try fm.copyItem(atPath: defaultRhythmFilePath, toPath: rt.file)
        reloadData()
    }
    
    private func setupNavBar() {
        let optionsItem = UIBarButtonItem(title: "Options", style: .plain, target: self, action: #selector(optionsAction))
        navigationItem.leftBarButtonItem = optionsItem
        
        let infoView = UIButton(type: .infoLight)
        infoView.addTarget(self, action: #selector(infoAction), for: .touchUpInside)
        let infoItem = UIBarButtonItem(customView: infoView)
        navigationItem.rightBarButtonItem = infoItem
    }
    
    private func setupRhythmsList() {
        reloadNSamples()
        
        let layout = UICollectionViewFlowLayout().then {
            $0.scrollDirection = .vertical
            $0.itemSize = CGSize(width: UIScreen.main.bounds.width - 20,
                                 height: 110)
            $0.minimumLineSpacing = 20
            $0.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        }
        _rhythmsListCV = UICollectionView(frame: view.bounds, collectionViewLayout: layout).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.backgroundColor = .clear
            $0.registerClass(for: RhythmCell.self)
            $0.dataSource = self
            $0.delegate = self
        }
        view.addSubview(_rhythmsListCV)
    }
    
    private func reloadNSamples() {
        _nSamplesList = RhythmType.allCases.map { rt in
            let rtDataStr = try! String(contentsOfFile: rt.file)
            return rtDataStr.split(separator: "\n").count
        }
    }
    
    private func reloadData() {
        reloadNSamples()
        _rhythmsListCV.reloadData()
    }
    
    @objc private func optionsAction() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Train", style: .default) { [weak self] _ in
                self?.present(NavigationController(rootViewController: TrainViewController()),
                        animated: true)
            }
        )
        alert.addAction(
            UIAlertAction(title: "Share Weights", style: .default) { [weak self] _ in
                let archiveUrl = try! RhythmNet.zipParams()
                let activity = UIActivityViewController(activityItems: [archiveUrl], applicationActivities: nil)
                self?.present(activity, animated: true)
            }
        )
        alert.addAction(
            UIAlertAction(title: "Restore Default Weights", style: .destructive) { _ in
                try! RhythmNet.restoreDefaultParamsIfNeeded()
            }
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func infoAction() {
        let alert = UIAlertController(title: nil, message: kInfo, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
}

extension RhythmsViewController : UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return RhythmType.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeue(for: RhythmCell.self, at: indexPath).then {
            $0.set(rhythmType: RhythmType.allCases[indexPath.row], nSamples: _nSamplesList[indexPath.row])
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let rt = RhythmType.allCases[indexPath.row]
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Reset to Default", style: .destructive) { [weak self] _ in
                let alert = UIAlertController(title: nil, message: "Are you sure?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "No", style: .default, handler: nil))
                alert.addAction(
                    UIAlertAction(title: "Yes", style: .destructive) { _ in
                        try! self?.resetToDefault(for: rt)
                    }
                )
                self?.present(alert, animated: true)
            }
        )
        alert.addAction(
            UIAlertAction(title: "Add Samples", style: .default) { [weak self] _ in
                self?.navigationController?
                    .pushViewController(
                        RecordViewController(rhythmType: rt, recordingMode: .add),
                        animated: true)
            }
        )
        alert.addAction(
            UIAlertAction(title: "Recreate Samples", style: .default) { [weak self] _ in
                self?.navigationController?
                    .pushViewController(
                        RecordViewController(rhythmType: rt, recordingMode: .create),
                        animated: true)
            }
        )
        alert.addAction(
            UIAlertAction(title: "Share", style: .default) { [weak self] _ in
                let activity = UIActivityViewController(activityItems: [URL(fileURLWithPath: rt.file)], applicationActivities: nil)
                self?.present(activity, animated: true)
            }
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
}
