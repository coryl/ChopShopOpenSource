//
//  PaintableImageView.swift
//  ChopShopOpenSource
//
//  Created by Cory Liu on 2021-06-10.
//

import UIKit

enum BrushType {
    case foreground, background, eraser
}

protocol PaintableViewDelegate: AnyObject {
    func didFinishPainting()
}

class PaintableImageView: UIImageView {
    private var lastPoint: CGPoint = .zero
    private var circleStroke: CAShapeLayer?
    private var brushSize: CGFloat = 15.0
    private var brushType: BrushType = .foreground
    private var brushColor: UIColor {
        switch self.brushType {
        case .foreground:
            return UIColor(red: 0.0/255, green: 255/255, blue: 0/255, alpha: 0.8)
        case .background:
            return UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 0.8)
        case .eraser:
            return UIColor.clear
        }
    }
    private var originalImageSize: CGSize!
    public weak var delegate: PaintableViewDelegate?
    
    private var pxWidthRatio: CGFloat {
        get {
            return originalImageSize.width/self.frame.width
        }
    }
    private var pxHeightRatio: CGFloat {
        get {
            return originalImageSize.height/self.frame.height
        }
    }
    
    init(frame:CGRect, imageSize: CGSize){
        super.init(frame: frame)
        
        self.originalImageSize = imageSize
        self.initCircleStroke()
        self.setBrushType(.foreground)
        self.clipsToBounds = true
        self.contentMode = .scaleAspectFit
        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initCircleStroke(){
        self.circleStroke = CAShapeLayer()
        self.circleStroke?.bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        self.circleStroke?.position = CGPoint.zero
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 40, height: 40))
        self.circleStroke?.path = path.cgPath
        self.circleStroke?.strokeColor = UIColor.clear.cgColor
        self.circleStroke?.lineWidth = 2.0
        self.circleStroke?.fillColor = UIColor.clear.cgColor
        self.layer.addSublayer(self.circleStroke!)
    }
    
    private func setPositionOfCircleStroke(_ point: CGPoint){
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.circleStroke?.position = point
        CATransaction.commit()
    }
    
    private func animateCircleStrokeFadeIn(){
        UIView.animate(withDuration: 0.25, animations: {
            self.circleStroke?.strokeColor = UIColor.white.cgColor
        })
    }
    
    private func animateCircleStrokeFadeOut(){
        UIView.animate(withDuration: 0.25, animations: {
            self.circleStroke?.strokeColor = UIColor.clear.cgColor
        })
    }

    public func setBrushType(_ brushType: BrushType){
        self.brushType = brushType
        switch brushType {
        case .foreground:
            self.brushSize = 15.0
        case .background:
            self.brushSize = 15.0
        case .eraser:
            self.brushSize = 22.0
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = self.delegate else { return }
        if let touch = touches.first {
            let point = touch.location(in: self)
            self.setPositionOfCircleStroke(point)
            self.animateCircleStrokeFadeIn()
            
            self.lastPoint = CGPoint(x: point.x * pxWidthRatio, y: point.y * pxHeightRatio)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = self.delegate, let imageSize = self.originalImageSize else { return }
        if let touch = touches.first {
            let point = touch.location(in: self)
            let currentPoint = CGPoint(x: point.x * pxWidthRatio, y: point.y * pxHeightRatio)
            
            UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
            
            self.image?.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
            UIGraphicsGetCurrentContext()?.move(to: lastPoint)
            UIGraphicsGetCurrentContext()?.addLine(to: currentPoint)
            UIGraphicsGetCurrentContext()?.setLineCap(.round)
            UIGraphicsGetCurrentContext()?.setLineWidth(self.brushSize * UIScreen.main.scale)
            
            UIGraphicsGetCurrentContext()?.setStrokeColor(self.brushColor.cgColor)
            
            if self.brushType == .eraser {
                UIGraphicsGetCurrentContext()?.setBlendMode(.clear)
            } else {
                UIGraphicsGetCurrentContext()?.setBlendMode(.normal)
            }
            
            UIGraphicsGetCurrentContext()?.strokePath()
            
            self.image = UIGraphicsGetImageFromCurrentImageContext()
            
            UIGraphicsEndImageContext()
            
            self.lastPoint = currentPoint
            self.setPositionOfCircleStroke(point)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = self.delegate else { return }
        self.animateCircleStrokeFadeOut()
        self.delegate?.didFinishPainting()
    }
}
