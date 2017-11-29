//
//  MomentCollectionViewCell.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-22.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

protocol MomentCollectionViewCellDelegate: class {
  func deleteMoment(sourceCell cell: MomentCollectionViewCell)
}


class MomentCollectionViewCell: UICollectionViewCell {
  
  // MARK: - Private Static Constants
  private struct Constants {
    static let CellCornerRadius: CGFloat = 5.0
    static let CellShadowColor = UIColor.black
    static let CellShadowOffset = CGSize(width: 0.0, height: 3.0)
    static let CellShadowRadius: CGFloat = 5.0
    static let CellShadowOpacity: Float = 0.25
    
    static let ThumbnailFrameLineWidth: CGFloat = 5.0
    static let AnimationRotateDegrees: CGFloat = 0.5
    static let AnimationTranslateX: CGFloat = 1.0
    static let AnimationTranslateY: CGFloat = 1.0
    static let Count: Int = 1
  }

  
  // MARK: - IBOutlets
  @IBOutlet weak var deleteButton: UIButton!
  @IBOutlet weak var momentThumb: UIImageView!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  
  
  // MARK: - IBActions
  @IBAction func deleteMomentButton(_ sender: UIButton) {
    delegate?.deleteMoment(sourceCell: self)
  }

  
  
  // MARK: - Public Instance Variable
  var indexPath: IndexPath?
  var thumbFrameLayer: ThumbnailFrameLayer?
  weak var delegate: MomentCollectionViewCellDelegate?
  
  
  
  // MARK: - Private Instance Functions
  fileprivate func degreesToRadians(x: CGFloat) -> CGFloat {
    return CGFloat(Double.pi) * x / 180.0
  }

  
  
  // MARK: - Public Instace Functions
  func configureLayers() {
    self.layer.masksToBounds = false
    self.layer.cornerRadius = Constants.CellCornerRadius
    self.layer.shadowColor = Constants.CellShadowColor.cgColor
    self.layer.shadowOffset = Constants.CellShadowOffset
    self.layer.shadowRadius = Constants.CellCornerRadius
    self.layer.shadowOpacity = Constants.CellShadowOpacity
    
    self.layer.shadowPath = UIBezierPath(roundedRect: layer.bounds, cornerRadius: layer.cornerRadius).cgPath
    
    momentThumb.layer.masksToBounds = true
    momentThumb.layer.cornerRadius = Constants.CellCornerRadius
    
    thumbFrameLayer = ThumbnailFrameLayer(frame: bounds)
    thumbFrameLayer!.lineWidth = Constants.ThumbnailFrameLineWidth
    thumbFrameLayer!.cornerRadius = Constants.CellCornerRadius
    thumbFrameLayer!.strokeColor = FoodieGlobal.Constants.ThemeColor.cgColor
    thumbFrameLayer!.isHidden = true
    momentThumb.layer.addSublayer(thumbFrameLayer!)
  }

  func stopWobble() {
    self.layer.removeAllAnimations()
    self.transform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.AnimationRotateDegrees * 0))
  }

  func wobble() {
    let leftOrRight: CGFloat = (Constants.Count % 2 == 0 ? 1 : -1)
    let rightOrLeft: CGFloat = (Constants.Count % 2 == 0 ? -1 : 1)
    let leftWobble: CGAffineTransform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.AnimationRotateDegrees * leftOrRight))
    let rightWobble: CGAffineTransform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.AnimationRotateDegrees * rightOrLeft))
    let moveTransform: CGAffineTransform = leftWobble.translatedBy(x: -Constants.AnimationTranslateX, y: -Constants.AnimationTranslateY)
    let conCatTransform: CGAffineTransform = leftWobble.concatenating(moveTransform)

    transform = rightWobble // starting point

    UIView.animate(withDuration: 0.10, delay: 0.10, options: [.allowUserInteraction, .repeat, .autoreverse], animations: { () -> Void in
      self.transform = conCatTransform
    }, completion: nil)
  }
}
