//
//  TrainLogsViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/7/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIKit
import SwiftMLP


final class TrainLogsViewController : TrainTabViewController {
    private var _logTextView: UITextView!
    private var _hintLbl: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
        setupHint()
    }
    
    private func setupTextView() {
        _logTextView = UITextView(frame: view.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.backgroundColor = .clear
            $0.textColor = .white
            $0.isEditable = false
            $0.isSelectable = false
            $0.text = ""
            $0.font = UIFont.systemFont(ofSize: 16)
        }
        view.addSubview(_logTextView)
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
            make.leading.equalToSuperview().offset(20).priority(.low)
            make.trailing.equalToSuperview().offset(-20).priority(.low)
            make.centerY.equalTo(_logTextView)
        }
    }
    
    override func onTrainBegan() {
        _logTextView.text = ""
        _hintLbl.isHidden = true
    }
    
    override func onEpochEnd(epoch: Int, log: Log) {
        var resLogStr = "\(log[.epochLogStr] as! String)\n\n"
        if let esLogStr = log[.esLogStr] as? String {
            resLogStr += "\(esLogStr)\n\n"
        }
        _logTextView.text += resLogStr
    }
}
