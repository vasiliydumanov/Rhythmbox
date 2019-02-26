//
//  GaussianGenerator.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/22/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import Foundation

final class GaussianGenerator {
    private var nextNextGaussian: Double? = {
        srand48(Int(arc4random())) //initialize drand48 buffer at most once
        return nil
    }()
    
    func nextGaussian() -> Double {
        if let gaussian = nextNextGaussian {
            nextNextGaussian = nil
            return gaussian
        } else {
            var v1, v2, s: Double
            
            repeat {
                v1 = 2 * drand48() - 1
                v2 = 2 * drand48() - 1
                s = v1 * v1 + v2 * v2
            } while s >= 1 || s == 0
            
            let multiplier = sqrt(-2 * log(s)/s)
            nextNextGaussian = v2 * multiplier
            return v1 * multiplier
        }
    }
}
