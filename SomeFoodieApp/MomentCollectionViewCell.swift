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
    static let thumbnailFrameInsetPct: CGFloat = 0.1
  }
  
  var thumbFrameLayer = ThumbnailFrameLayer()
  
//  override init(frame: CGRect) {
//    super.init(frame: frame)
//    self.frame = frame
//    createLayers()
//  }
//  
//  required init?(coder aDecoder: NSCoder) {
//    super.init(coder: aDecoder)
//    createLayers()
//  }
  
  // CONTINUE-HERE: WTF is wrong with the frame that it's not centered?
  
  func createFrameLayer() {
    thumbFrameLayer = ThumbnailFrameLayer(frame: bounds.insetBy(dx: bounds.maxX*Constants.thumbnailFrameInsetPct,
                                                                dy: bounds.maxY*Constants.thumbnailFrameInsetPct))
    thumbFrameLayer.lineWidth = 5.0
    thumbFrameLayer.strokeColor = UIColor.orange.cgColor
    thumbFrameView.layer.addSublayer(thumbFrameLayer)
  }
}
