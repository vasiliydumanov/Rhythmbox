//
//  Reusable.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 3/4/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation
import UIKit

protocol Reusable : class {
    static var reuseId: String { get }
}

extension UICollectionView {
    func registerClass<Cell : UICollectionViewCell>(for cell: Cell.Type) where Cell : Reusable {
        register(Cell.self, forCellWithReuseIdentifier: cell.reuseId)
    }
    
    func dequeue<Cell : UICollectionViewCell>(for cell: Cell.Type, at ip: IndexPath) -> Cell where Cell : Reusable {
        return dequeueReusableCell(withReuseIdentifier: Cell.reuseId, for: ip) as! Cell
    }
}
