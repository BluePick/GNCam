//
//  ViewController.swift
//  GNCam
//
//  Created by gonzalonunez on 08/08/2016.
//  Copyright (c) 2016 gonzalonunez. All rights reserved.
//

import UIKit

import AVFoundation
import CoreMedia

import GNCam

class ViewController: UIViewController, VideoPreviewLayerProvider {
  
  static private let captureButtonRestingRadius: CGFloat = 3
  static private let captureButtonElevatedRadius: CGFloat = 7
  
  @IBOutlet weak private var imageView: UIImageView!
  @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
  
  @IBOutlet weak private var captureButton: UIButton!
  
  @IBOutlet private var viewTap: UITapGestureRecognizer!
  @IBOutlet private var viewDoubleTap: UITapGestureRecognizer!
  
  var previewLayer: AVCaptureVideoPreviewLayer {
    return view.layer as! AVCaptureVideoPreviewLayer
  }
    
  override func viewDidLoad() {
    super.viewDidLoad()
        
    viewTap.require(toFail: viewDoubleTap)
    
    setUpCaptureButton()
    setUpCaptureManager()
    
    captureManager.startRunning()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refreshImageViewDimensions()
  }
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    refreshImageViewDimensions()
    captureManager.refreshOrientation()
  }
  
  private func refreshImageViewDimensions() {
    let maxDim = max(view.bounds.height, view.bounds.width)
    let minDim = min(view.bounds.height, view.bounds.width)
    
    imageViewHeightConstraint.constant = (captureManager.desiredVideoOrientation == .portrait ? maxDim : minDim) * 0.4
    imageViewWidthConstraint.constant = (captureManager.desiredVideoOrientation == .portrait ? minDim : maxDim) * 0.4
    view.layoutIfNeeded()
  }
  
  private func setUpCaptureButton() {
    captureButton.layer.cornerRadius = 40
    captureButton.layer.shadowColor = UIColor.black.cgColor
    captureButton.layer.shadowOpacity = 0.5
    captureButton.layer.shadowOffset = CGSize(width: 0, height: 2)
    captureButton.layer.shadowRadius = ViewController.captureButtonRestingRadius
  }
  
  private func setUpCaptureManager() {
    captureManager.dataOutputDelegate = self
    captureManager.setUp(sessionPreset: AVCaptureSessionPresetHigh,
                         previewLayerProvider: self,
                         inputs: [.video],
                         outputs: [.stillImage, .videoData])
    { (error) in
      print("Woops, got error: \(error)")
    }
  }
  
  //MARK: IBActions
  
  @IBAction func handleCaptureButtonTouchDown(_ sender: UIButton) {
    captureButton.layer.animateShadowRadius(to: ViewController.captureButtonElevatedRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(0.7)
  }
  
  @IBAction func handleCaptureButtonTouchUpOutside(_ sender: UIButton) {
    captureButton.layer.animateShadowRadius(to: ViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)
  }
  
  @IBAction func handleCaptureButtonTouchUpInside(_ sender: UIButton) {
    captureButton.layer.animateShadowRadius(to: ViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)

    captureManager.captureStillImage() { (image, error) in
      self.imageView.image = image
    }
 }
  
  @IBAction func handleViewTap(_ tap: UITapGestureRecognizer) {
    let loc = tap.location(in: view)
    captureManager.focusAndExposure(at: loc)
  }
  
  @IBAction func handleViewDoubleTap(_ sender: UITapGestureRecognizer) {
    captureManager.toggleCamera() { (error) -> Void in
      print("Woops, got error: \(error)")
    }
  }
  
}

extension ViewController: VideoDataOutputDelegate {
  
  func captureManagerDidOutput(sampleBuffer: CMSampleBuffer) {
    //print("\(NSDate()) Capture manager did output a buffer.")
  }
  
}

private extension CALayer {
  
  func animateShadowRadius(to radius: CGFloat) {
    let key = "com.ZenunSoftware.GNCam.animateShadowRadius"
    
    removeAnimation(forKey: key)
    
    let anim = CABasicAnimation(keyPath: #keyPath(shadowRadius))
    anim.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    anim.toValue = radius
    anim.duration = 0.2
    
    add(anim, forKey: key)
    shadowRadius = radius
  }
  
}
