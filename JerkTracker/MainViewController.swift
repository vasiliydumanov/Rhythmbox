//
//  MainViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import Then
import SnapKit

class MainViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        let buttonsStack = UIStackView().then {
            $0.axis = .vertical
            $0.spacing = 20
            $0.alignment = .center
        }
        view.addSubview(buttonsStack)
        buttonsStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        let jerksListBtn = UIButton(type: .system).then {
            $0.setTitle("Jerks List", for: .normal)
            $0.setTitleColor(.white, for: .normal)
        }
        jerksListBtn.addTarget(self, action: #selector(jerksListAction), for: .touchUpInside)
        buttonsStack.addArrangedSubview(jerksListBtn)
        
        let demoBtn = UIButton(type: .system).then {
            $0.setTitle("Demo", for: .normal)
            $0.setTitleColor(.white, for: .normal)
        }
        demoBtn.addTarget(self, action: #selector(demoAction), for: .touchUpInside)
        buttonsStack.addArrangedSubview(demoBtn)
        
        let trainBtn = UIButton(type: .system).then {
            $0.setTitle("Train", for: .normal)
            $0.setTitleColor(.white, for: .normal)
        }
        trainBtn.addTarget(self, action: #selector(trainAction), for: .touchUpInside)
        buttonsStack.addArrangedSubview(trainBtn)
    }
    
    @objc private func jerksListAction() {
        navigationController?.pushViewController(
            JerksListViewController(nibName: nil, bundle: nil),
            animated: true
        )
    }
    
    @objc private func demoAction() {
        navigationController?.pushViewController(
            DemoViewController(nibName: nil, bundle: nil),
            animated: true
        )
    }
    
    @objc private func trainAction() {
        navigationController?.pushViewController(
            TrainViewController(nibName: nil, bundle: nil),
            animated: true
        )
    }
}
