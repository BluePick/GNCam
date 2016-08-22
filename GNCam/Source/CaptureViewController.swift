//
//  CaptureViewController.swift
//  Pods
//
//  Created by Gonzalo Nunez on 8/21/16.
//
//

import AVFoundation
import CoreMedia

import UIKit

public protocol CaptureViewControllerDelegate: class {
  func captureViewController(_ controller: CaptureViewController, didCaptureStillImage image: UIImage?)
}

open class CaptureViewController: UIViewController, VideoPreviewLayerProvider {
  
  static fileprivate let captureButtonRestingRadius: CGFloat = 3
  static fileprivate let captureButtonElevatedRadius: CGFloat = 7
  
  open var inputs = [CaptureSessionInput.video] {
    didSet {
      didChangeInputsOrOutputs()
    }
  }
  
  open var outputs = [CaptureSessionOutput.stillImage] {
    didSet {
      didChangeInputsOrOutputs()
    }
  }
  
  public var dismissable = true {
    didSet {
      closeButton.isHidden = !dismissable
    }
  }
  
  public weak var captureDelegate: CaptureViewControllerDelegate?
  
  fileprivate lazy var closeButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    
    btn.layer.borderColor = UIColor.red.cgColor
    btn.layer.borderWidth = 2
    
    //FIXME: `close` is nil :(
    let type = type(of: self)
    let bundle = Bundle(for: type)
    let close = UIImage(named: "close", in: bundle, compatibleWith: nil)
    
    btn.setImage(close, for: .normal)
    btn.addTarget(self, action: #selector(handleCloseButton(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  fileprivate lazy var cameraSwitchButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    
    btn.layer.borderColor = UIColor.red.cgColor
    btn.layer.borderWidth = 2
    
    //FIXME: `switchCamera` is nil :(
    let type = type(of: self)
    let bundle = Bundle(for: type)
    let switchCamera = UIImage(named: "switchCamera", in: bundle, compatibleWith: nil)
        
    btn.setImage(switchCamera, for: .normal)
    btn.addTarget(self, action: #selector(handleCameraSwitchButton(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  fileprivate lazy var captureButton: UIButton = {
    let btn = UIButton(frame: CGRect.zero)
    btn.backgroundColor = .white
    
    btn.layer.cornerRadius = 40
    btn.layer.shadowColor = UIColor.black.cgColor
    btn.layer.shadowOpacity = 0.5
    btn.layer.shadowOffset = CGSize(width: 0, height: 2)
    btn.layer.shadowRadius = CaptureViewController.captureButtonRestingRadius
    
    btn.addTarget(self, action: #selector(handleCaptureButtonTouchDown(_:)), for: .touchDown)
    btn.addTarget(self, action: #selector(handleCaptureButtonTouchUpOutside(_:)), for: .touchUpOutside)
    btn.addTarget(self, action: #selector(handleCaptureButtonTouchUpInside(_:)), for: .touchUpInside)
    
    return btn
  }()
  
  fileprivate lazy var viewTap: UITapGestureRecognizer = {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewTap(_:)))
    tap.delaysTouchesEnded = false
    return tap
  }()
  
  
  fileprivate lazy var viewDoubleTap: UITapGestureRecognizer = {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewDoubleTap(_:)))
    tap.delaysTouchesEnded = false
    tap.numberOfTapsRequired = 2
    return tap
  }()
  
  public convenience init(inputs: [CaptureSessionInput], outputs:[CaptureSessionOutput]) {
    self.init(nibName: nil, bundle: nil)
    self.inputs = inputs
    self.outputs = outputs
  }
  
  override open func viewDidLoad() {
    super.viewDidLoad()
    setUp()
  }
    
  override open func loadView() {
    view = CapturePreviewView()
  }
  
  override open var prefersStatusBarHidden: Bool {
    return true
  }
  
  override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    captureManager.refreshOrientation()
  }
  
  //MARK: Set Up
  
  fileprivate func setUp() {
    setUpButtons()
    setUpGestures()
    setUpCaptureManager()
  }
  
  fileprivate func setUpButtons() {
    setUpCloseButton()
    setUpCameraSwitchButton()
    setUpCaptureButton()
  }
  
  fileprivate func setUpCloseButton() {
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(closeButton)
    
    let top = closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
    let left = closeButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16)
    let width = closeButton.widthAnchor.constraint(equalToConstant: 44)
    let height = closeButton.heightAnchor.constraint(equalToConstant: 44)
    
    NSLayoutConstraint.activate([top, left, width, height])
  }
  
  fileprivate func setUpCameraSwitchButton() {
    cameraSwitchButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cameraSwitchButton)
    
    let top = cameraSwitchButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 16)
    let right = cameraSwitchButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16)
    let width = cameraSwitchButton.widthAnchor.constraint(equalToConstant: 44)
    let height = cameraSwitchButton.heightAnchor.constraint(equalToConstant: 44)
    
    NSLayoutConstraint.activate([top, right, width, height])
  }
  
  fileprivate func setUpCaptureButton() {
    captureButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(captureButton)
    
    let bottom = captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
    let centerX = captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    let width = captureButton.widthAnchor.constraint(equalToConstant: 80)
    let height = captureButton.heightAnchor.constraint(equalToConstant: 80)
    
    NSLayoutConstraint.activate([bottom, centerX, width, height])
  }
  
  fileprivate func setUpGestures() {
    view.addGestureRecognizer(viewTap)
    view.addGestureRecognizer(viewDoubleTap)
    
    viewTap.require(toFail: viewDoubleTap)
  }
  
  fileprivate func setUpCaptureManager() {
    captureManager.setUp(sessionPreset: AVCaptureSessionPresetHigh,
                         previewLayerProvider: self,
                         inputs: [.video],
                         outputs: [.stillImage])
    { (error) in
      print("Woops, got error: \(error)")
    }
    
    captureManager.startRunning()
  }
  
  //MARK: Actions
  
  @objc fileprivate func handleCloseButton(_: UIButton) {
    
  }
  
  @objc fileprivate func handleCameraSwitchButton(_: UIButton) {
    toggleCamera()
  }
  
  @objc fileprivate func handleCaptureButtonTouchDown(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonElevatedRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(0.7)
  }
  
  @objc fileprivate func handleCaptureButtonTouchUpOutside(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)
  }
  
  @objc fileprivate func handleCaptureButtonTouchUpInside(_: UIButton) {
    captureButton.layer.animateShadowRadius(to: CaptureViewController.captureButtonRestingRadius)
    captureButton.backgroundColor = captureButton.backgroundColor?.withAlphaComponent(1)
    
    captureManager.captureStillImage() { (image, error) in
      self.captureDelegate?.captureViewController(self, didCaptureStillImage: image)
    }
  }
  
  //MARK: Gestures
  
  @objc fileprivate func handleViewTap(_ tap: UITapGestureRecognizer) {
    let loc = tap.location(in: view)
    
    do {
      try captureManager.focusAndExposure(at: loc)
      showIndicatorView(at: loc)
    } catch let error {
      print("Woops, got error: \(error)")
    }
  }
  
  open func showIndicatorView(at loc: CGPoint) {
    let indicator = FocusIndicatorView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
    indicator.center = loc
    indicator.backgroundColor = .clear
    
    view.addSubview(indicator)
    
    indicator.popUpDown() { _ -> Void in
      indicator.removeFromSuperview()
    }
  }
  
  @objc fileprivate func handleViewDoubleTap(_ tap: UITapGestureRecognizer) {
    toggleCamera()
  }

  //MARK: VideoPreviewLayerProvider
  
  open var previewLayer: AVCaptureVideoPreviewLayer {
    return view.layer as! AVCaptureVideoPreviewLayer
  }
  
  //MARK: Helpers
  
  fileprivate func toggleCamera() {
    captureManager.toggleCamera() { (error) -> Void in
      print("Woops, got error: \(error)")
    }
  }
  
  fileprivate func didChangeInputsOrOutputs() {
    let wasRunning = captureManager.isRunning
    captureManager.stopRunning()
    setUpCaptureManager()
    if (wasRunning) { captureManager.startRunning() }
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
