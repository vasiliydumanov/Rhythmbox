//
//  NavigationController.swift
//  Rhythmbox
//
//  Created by Vasiliy Dumanov on 3/4/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import UIColor_Hex_Swift

class NavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.do {
            $0.tintColor = Theme.default.text
            $0.isTranslucent = false
            $0.barTintColor = Theme.default.barsAndHeaders
            $0.titleTextAttributes = [.foregroundColor : Theme.default.text]
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.default.barStyle
    }

}
