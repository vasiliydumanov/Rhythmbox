//
//  RhythmCell.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/4/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import Then
import SnapKit

class RhythmCell: UICollectionViewCell, Reusable {
    static let reuseId = "RhythmCell"
    
    private var _typeLbl: UILabel!
    private var _nSamplesLbl: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        contentView.do {
            $0.layer.cornerRadius = 8
            $0.backgroundColor = Theme.default.cardsBody
            $0.clipsToBounds = true
        }
        
        let typeHeader = UIView().then {
            $0.backgroundColor = Theme.default.cardsHeader
        }
        contentView.addSubview(typeHeader)
        typeHeader.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(50)
        }
        
        _typeLbl = UILabel().then {
            $0.textColor = Theme.default.text
            $0.font = .boldSystemFont(ofSize: 18)
        }
        typeHeader.addSubview(_typeLbl)
        _typeLbl.snp.makeConstraints{ make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        
        _nSamplesLbl = UILabel().then {
            $0.font = .systemFont(ofSize: 20)
            $0.textColor = Theme.default.text
            $0.textAlignment = .center
        }
        contentView.addSubview(_nSamplesLbl)
        _nSamplesLbl.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(typeHeader.snp.bottom)
            make.bottom.equalToSuperview()
        }
    }
    
    func set(rhythmType: RhythmType, nSamples: Int) {
        _typeLbl.text = rhythmType.displayedName
        _nSamplesLbl.text = "\(nSamples) samples"
    }
}
