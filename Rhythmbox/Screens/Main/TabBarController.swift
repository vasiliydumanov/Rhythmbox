//
//  TabBarController.swift
//  Rhythmbox
//
//  Created by Vasiliy Dumanov on 3/4/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit


class TabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        typealias ControllerData = (vc: UIViewController, image: UIImage)
        let data: [ControllerData] = [
            (RhythmsViewController(), #imageLiteral(resourceName: "tb_player")),
            (PlayerViewController(), #imageLiteral(resourceName: "tb_rhythms")),
        ]
        
        viewControllers = data
            .map { vc, image in
                NavigationController(rootViewController: vc).then {
                    $0.tabBarItem = UITabBarItem(title: vc.title, image: image, selectedImage: nil)
                }
            }
        
        tabBar.do {
            $0.tintColor = Theme.default.text
            $0.isTranslucent = false
            $0.barTintColor = Theme.default.barsAndHeaders
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.default.barStyle
    }
}
