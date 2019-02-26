//
//  ChartView.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit

final class Highlight {
    var leftOffset: Int = 0
    var rightOffset: Int = 0
}

class ChartView: UIView {
    var yRange: ClosedRange<Double> = (-3.0...3.0)
    var xIntervalsNum: Int = 120
    var chartColor: UIColor = UIColor.white
    var axesColor: UIColor = UIColor.lightGray
    var highlightColor: UIColor = UIColor.darkGray
    var axesSpacing: Double = 0.5
    private var _yCoords: [Double] = []
    private var _highlightingJustBegan = false
    private var _isHighlighting = false
    private var _highlights: [Highlight] = []
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func add(yCoord: Double) {
        _yCoords.append(yCoord)
        if _yCoords.count > xIntervalsNum + 1 {
            _yCoords.removeFirst()
        }
        if
            let firstHighlight = _highlights.first,
            firstHighlight.rightOffset >= xIntervalsNum
        {
            _highlights.removeFirst()
        }
        if _highlightingJustBegan {
            _highlightingJustBegan = false
            _highlights.append(Highlight())
        }
        for (idx, highlight) in _highlights.enumerated() {
            highlight.leftOffset += 1
            if !(_isHighlighting && idx == _highlights.count - 1) {
                highlight.rightOffset += 1
            }
        }
        setNeedsDisplay()
    }
    
    func startHighlighting() {
        _isHighlighting = true
        _highlightingJustBegan = true
    }
    
    func stopHighlighting() {
        _isHighlighting = false
    }
    
    override func draw(_ rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()!
        (backgroundColor ?? .black).setFill()
        ctx.fill(rect)
        
        for highlight in _highlights {
            let leftX = frame.width - (frame.width / CGFloat(xIntervalsNum)) * CGFloat(highlight.leftOffset)
            let width = CGFloat(highlight.leftOffset - highlight.rightOffset) * (frame.width / CGFloat(xIntervalsNum))
            let highlightRect = CGRect(x: leftX,
                                       y: 0,
                                       width: width,
                                       height: frame.height)
            highlightColor.setFill()
            ctx.fill(highlightRect)
        }
        
        let upperAxesBound = floor(yRange.upperBound / axesSpacing) * axesSpacing
        let axesSteps = Int(floor((upperAxesBound - yRange.lowerBound) / axesSpacing))
        let axesSpacingTransformed = CGFloat(axesSpacing / (yRange.upperBound - yRange.lowerBound)) * frame.height
        let upperAxesBoundTransformed = CGFloat((yRange.upperBound - upperAxesBound) / (yRange.upperBound - yRange.lowerBound)) * frame.height
        axesColor.setStroke()
        for step in 0...axesSteps {
            let axesY = upperAxesBoundTransformed + CGFloat(step) * axesSpacingTransformed
            let axesPath = UIBezierPath()
            axesPath.move(to: CGPoint(x: 0, y: axesY))
            axesPath.addLine(to: CGPoint(x: rect.width, y: axesY))
            axesPath.lineWidth = 1
            axesPath.stroke()
        }
        
        let paddedYCoords: [Double]
        if _yCoords.count < xIntervalsNum + 1 {
            let padding = Array<Double>(repeating: 0, count: xIntervalsNum + 1 - _yCoords.count)
            paddedYCoords = padding + _yCoords
        } else {
            paddedYCoords = _yCoords
        }
        let xIntervalLength = rect.width / CGFloat(xIntervalsNum)
        let xCoords = (0..<xIntervalsNum + 1).map { idx in CGFloat(idx) * xIntervalLength }
        
        let points = zip(xCoords, paddedYCoords).map { (arg) -> CGPoint in
            let (xCoord, relYCoord) = arg
            let yCoord = CGFloat((self.yRange.upperBound - relYCoord) / (self.yRange.upperBound - self.yRange.lowerBound)) * frame.height
            return CGPoint(x: xCoord, y: yCoord)
        }
        
        let chartPath = UIBezierPath()
        chartPath.lineWidth = 2
        chartPath.move(to: points[0])
        for point in points.dropFirst() {
            chartPath.addLine(to: point)
        }
        chartColor.setStroke()
        chartPath.stroke()
    }
}
