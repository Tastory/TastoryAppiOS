//
//  MomentCollectionViewCell.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-22.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import UIKit

class MomentCollectionViewCell: UICollectionViewCell {
  @IBOutlet weak var momentButton: UIButton!
  @IBOutlet weak var thumbFrameView: UIView!
  
  private struct Constants {
    static let thumbnailFrameLineWidth: CGFloat = 10.0
  }
  
  var thumbFrameLayer = ThumbnailFrameLayer()
  
  func createFrameLayer() {
    thumbFrameLayer = ThumbnailFrameLayer(frame: bounds) // bounds.insetBy(dx: bounds.maxX*Constants.thumbnailFrameInsetPct,
                                                         //       dy: bounds.maxY*Constants.thumbnailFrameInsetPct))
    thumbFrameLayer.lineWidth = Constants.thumbnailFrameLineWidth
    thumbFrameLayer.strokeColor = FoodieConstants.ThemeColor.cgColor
    thumbFrameView.layer.addSublayer(thumbFrameLayer)
  }
}
