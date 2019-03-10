//
//  TrainTabViewController.swift
//  Rhythmbox
//
//  Created by Vasiliy Dumanov on 3/7/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIKit
import SwiftMLP

class TrainTabViewController : ViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func onTrainBegan() {
    }
    
    func onEpochEnd(epoch: Int, log: Log) {
    }
    
    func onTrainEnded() {
    }
}
