//
//  MainViewController.swift
//  ChopShopOpenSource
//
//  Created by Cory Liu on 2021-06-09.
//

import UIKit
import MBProgressHUD

class MainViewController: UIViewController {
    private var canvasImageView: CanvasImageView!
    private var resultImageView: UIImageView!
    private var greenMarkerButton: UIButton!
    private var redMarkerButton: UIButton!
    private var eraserButton: UIButton!
    private var nextButton: UIButton!
    private var images: [UIImage] = [UIImage(named: "basketball.jpg")!, UIImage(named: "dog.jpg")!]
    private var currentImageIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupCanvas()
        self.setupButtons()
        self.setupResult()
    }
    
    private func setupCanvas(){
        let viewWidth = self.view.frame.size.width
        self.canvasImageView = CanvasImageView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: viewWidth))
        self.canvasImageView.image = self.images.first!
        self.canvasImageView.delegate = self
        self.view.addSubview(self.canvasImageView)
    }
    
    private func setupButtons(){
        self.greenMarkerButton  = UIButton(type: .custom)
        self.greenMarkerButton.frame = CGRect(x: 0, y: self.canvasImageView.frame.origin.y + self.canvasImageView.frame.height, width: 30, height: 30)
        self.greenMarkerButton.setImage(UIImage(named: "green_marker.png"), for: .normal)
        self.greenMarkerButton.addTarget(self, action: #selector(self.changeBrushType), for: .touchUpInside)
        self.view.addSubview(self.greenMarkerButton)
        
        self.redMarkerButton  = UIButton(type: .custom)
        self.redMarkerButton.frame = CGRect(x: self.greenMarkerButton.frame.origin.x + self.greenMarkerButton.frame.size.width + 5, y: self.canvasImageView.frame.origin.y + self.canvasImageView.frame.height, width: 30, height: 30)
        self.redMarkerButton.setImage(UIImage(named: "red_marker.png"), for: .normal)
        self.redMarkerButton.addTarget(self, action: #selector(self.changeBrushType), for: .touchUpInside)
        self.view.addSubview(self.redMarkerButton)
        
        self.eraserButton  = UIButton(type: .custom)
        self.eraserButton.frame = CGRect(x: self.redMarkerButton.frame.origin.x + self.redMarkerButton.frame.size.width + 5, y: self.canvasImageView.frame.origin.y + self.canvasImageView.frame.height, width: 30, height: 30)
        self.eraserButton.setImage(UIImage(named: "eraser.png"), for: .normal)
        self.eraserButton.addTarget(self, action: #selector(self.changeBrushType), for: .touchUpInside)
        self.view.addSubview(self.eraserButton)
        
        self.nextButton = UIButton(type: .custom)
        self.nextButton.setTitle("Next", for: .normal)
        self.nextButton.setTitleColor(UIColor.blue, for: .normal)
        self.nextButton.sizeToFit()
        self.nextButton.frame = CGRect(x: self.eraserButton.frame.origin.x + self.eraserButton.frame.width + 10, y: self.canvasImageView.frame.origin.y + self.canvasImageView.frame.height, width: self.nextButton.frame.width, height: self.nextButton.frame.height)
        self.nextButton.addTarget(self, action: #selector(self.nextButtonTapped), for: .touchUpInside)
        self.view.addSubview(self.nextButton)
    }
    
    private func setupResult(){
        let viewWidth = self.view.frame.size.width

        self.resultImageView = UIImageView(frame: CGRect(x:0, y: self.greenMarkerButton.frame.origin.y + self.greenMarkerButton.frame.size.height, width: viewWidth, height: viewWidth))
        self.resultImageView.contentMode = .scaleAspectFit
        self.resultImageView.backgroundColor = UIColor.init(patternImage: UIImage(named: "checker.png")!)
        self.view.addSubview(self.resultImageView!)
    }
    
    @objc func changeBrushType(_ sender: UIButton){
        switch sender {
        case self.greenMarkerButton:
            self.canvasImageView.setBrushType(.foreground)
        case self.redMarkerButton:
            self.canvasImageView.setBrushType(.background)
        case self.eraserButton:
            self.canvasImageView.setBrushType(.eraser)
        default:
            break
        }
    }
    
    @objc func nextButtonTapped(_ sender: UIButton){
        self.currentImageIndex += 1
        if self.currentImageIndex > self.images.count-1 {
            self.currentImageIndex = 0
        }
        
        let image = self.images[self.currentImageIndex]
        self.canvasImageView.image = image
    }
}

extension MainViewController: CanvasImageViewDelegate{
    func beginGrabcutSequence() {
        guard let sourceImage = self.canvasImageView?.image, let maskImage = self.canvasImageView?.maskImage else {
            print("Need both source image and mask image")
            return
        }

        MBProgressHUD.showAdded(to: self.resultImageView!, animated: true)
        DispatchQueue.global().async {
            let results = OpenCVWrapper.applyGrabCut(withDownSample: false, sourceImage: sourceImage, maskImage: maskImage)
           
            DispatchQueue.main.async {
                MBProgressHUD.hide(for: self.resultImageView!, animated: true)
                if let finalImage = results["finalImage"] as? UIImage {
                    self.resultImageView?.image = finalImage
                }
                
                if let contourImage = results["contourImage"] as? UIImage {
                    self.canvasImageView?.updateContourImage(contourImage)
                }
            }
        }
    }
}
