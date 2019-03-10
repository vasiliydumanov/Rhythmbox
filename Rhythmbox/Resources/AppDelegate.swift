//
//  AppDelegate.swift
//  Rhythmbox
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAudioSession()
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootVC = TabBarController()
        window?.rootViewController = rootVC
        window?.makeKeyAndVisible()
        return true
    }
    
    private func configureAudioSession() {
        do {

            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
    }

}

