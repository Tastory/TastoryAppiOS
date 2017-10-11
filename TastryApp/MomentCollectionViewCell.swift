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
  @IBOutlet weak var momentThumb: UIImageView!
  @IBOutlet weak var thumbFrameView: UIView!
  weak var delegate: MomentCollectionViewCellDelegate?

  // MARK: - Private Static Constants
  private struct Constants {
    static let thumbnailFrameLineWidth: CGFloat = 10.0
    static let thumbnailFrameCornerRadius: CGFloat = 0.0
    static let animationRotateDegrees: CGFloat = 0.5
    static let animationTranslateX: CGFloat = 1.0
    static let animationTranslateY: CGFloat = 1.0
    static let count: Int = 1
  }

  // MARK: - IBActions
  @IBAction func deleteMomentButton(_ sender: UIButton) {
    delegate?.deleteMoment(sourceCell: self)
  }

  // MARK: - Public Instance Variable
  var thumbFrameLayer = ThumbnailFrameLayer()

  // MARK: - Private Instance Functions
  fileprivate func degreesToRadians(x: CGFloat) -> CGFloat {
    return CGFloat(Double.pi) * x / 180.0
  }

  // MARK: - Public Instace Functions
  func createFrameLayer() {
    thumbFrameLayer = ThumbnailFrameLayer(frame: bounds)
    thumbFrameLayer.lineWidth = Constants.thumbnailFrameLineWidth
    thumbFrameLayer.cornerRadius = Constants.thumbnailFrameCornerRadius
    thumbFrameLayer.strokeColor = FoodieGlobal.Constants.ThemeColor.cgColor
    thumbFrameView.layer.addSublayer(thumbFrameLayer)
  }

  func stopWobble() {
    self.layer.removeAllAnimations()
    self.transform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.animationRotateDegrees * 0))
  }

  func wobble() {
    let leftOrRight: CGFloat = (Constants.count % 2 == 0 ? 1 : -1)
    let rightOrLeft: CGFloat = (Constants.count % 2 == 0 ? -1 : 1)
    let leftWobble: CGAffineTransform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.animationRotateDegrees * leftOrRight))
    let rightWobble: CGAffineTransform = CGAffineTransform(rotationAngle: degreesToRadians(x: Constants.animationRotateDegrees * rightOrLeft))
    let moveTransform: CGAffineTransform = leftWobble.translatedBy(x: -Constants.animationTranslateX, y: -Constants.animationTranslateY)
    let conCatTransform: CGAffineTransform = leftWobble.concatenating(moveTransform)

    transform = rightWobble // starting point

    UIView.animate(withDuration: 0.10, delay: 0.10, options: [.allowUserInteraction, .repeat, .autoreverse], animations: { () -> Void in
      self.transform = conCatTransform
    }, completion: nil)
  }


}
