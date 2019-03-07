//
//  Theme.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/6/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIColor_Hex_Swift
import UIKit

struct Theme {
    let background: UIColor
    let barsAndHeaders: UIColor
    let cardsHeader: UIColor
    let cardsBody: UIColor
    let record: UIColor
    let text: UIColor
    let barStyle: UIStatusBarStyle
    
    static let `default`: Theme = .greyBlue
    
    static let greyBlue = Theme(background: UIColor("#424242"),
                                barsAndHeaders: UIColor("#212121"),
                                cardsHeader: UIColor("#1976d2"),
                                cardsBody: UIColor("#64b5f6"),
                                record: UIColor("#f44336"),
                                text: UIColor.white,
                                barStyle: .lightContent)
}
