//
//  CanvasImageView.swift
//  ChopShopOpenSource
//
//  Created by Cory Liu on 2021-06-09.
//

import UIKit

protocol CanvasImageViewDelegate: AnyObject {
    func beginGrabcutSequence()
}

class CanvasImageView: UIImageView {
    private var paintableImageView: PaintableImageView?
    public var maskImage: UIImage? {
        get {
            //Need to scale up the paintableImageView image from native device scale to match the source image's dimensions:
            func scaledPaintedImageForGrabcut() -> UIImage? {
                guard let image = self.image else { return nil }
                var paintBrushImageScaled: UIImage
                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                self.paintableImageView?.image?.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height), blendMode: CGBlendMode.normal, alpha: 1)
                paintBrushImageScaled = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()
                return paintBrushImageScaled
            }
            guard let _ = self.paintableImageView?.image else { return nil }
            
            return scaledPaintedImageForGrabcut()
        }
    }
    private var contourImageView: UIImageView?
    public weak var delegate: CanvasImageViewDelegate?
    override var image: UIImage? {
        didSet {
            self.initPaintableView()
            self.initContourImageView()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.gray
        self.isUserInteractionEnabled = true
        self.contentMode = .scaleAspectFit
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setBrushType(_ brushType: BrushType){
        self.paintableImageView?.setBrushType(brushType)
    }
   
    private func initPaintableView(){
        guard let image = self.image else { return }
        func frame(for image: UIImage, inImageViewAspectFit imageView: UIImageView) -> CGRect {
            let imageRatio = (image.size.width / image.size.height)
            let viewRatio = imageView.frame.size.width / imageView.frame.size.height
            if imageRatio < viewRatio {
                let scale = imageView.frame.size.height / image.size.height
                let width = scale * image.size.width
                let topLeftX = (imageView.frame.size.width - width) * 0.5
                return CGRect(x: topLeftX, y: 0, width: width, height: imageView.frame.size.height)
            } else {
                let scale = imageView.frame.size.width / image.size.width
                let height = scale * image.size.height
                let topLeftY = (imageView.frame.size.height - height) * 0.5
                return CGRect(x: 0.0, y: topLeftY, width: imageView.frame.size.width, height: height)
            }
        }
        
        let displayedImageFrame = frame(for: image, inImageViewAspectFit: self) //the CGRect of the actual image displayed, after scaling is done by .aspectFit
        
        if (self.paintableImageView != nil) {
            self.paintableImageView?.removeFromSuperview()
        }
        
        self.paintableImageView = PaintableImageView(frame: displayedImageFrame, imageSize: image.size)
        self.paintableImageView?.delegate = self
        self.addSubview(self.paintableImageView!)
    }
    
    private func initContourImageView(){
        if (self.contourImageView != nil){
            self.contourImageView?.removeFromSuperview()
        }
        
        self.contourImageView = UIImageView(frame: self.frame)
        self.contourImageView?.contentMode = .scaleAspectFit
        self.addSubview(self.contourImageView!)
    }
    
    public func updateContourImage(_ contourImage: UIImage){
        self.contourImageView?.image = contourImage
    }
}

extension CanvasImageView: PaintableViewDelegate {
    func didFinishPainting() {
        self.delegate?.beginGrabcutSequence()
    }
}
