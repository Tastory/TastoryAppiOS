//
//  MomentCollectionViewCell.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-04-22.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

protocol MomentCollectionViewCellDelegate: class {
  func deleteMoment(sourceCell cell: MomentCollectionViewCell)
}


class MomentCollectionViewCell: UICollectionViewCell {
  @IBOutlet weak var momentThumb: UIImageView!
  @IBOutlet weak var thumbFrameView: UIView!
  weak var delegate: MomentCollectionViewCellDelegate?

  private struct Constants {
    static let thumbnailFrameLineWidth: CGFloat = 10.0
  }

  @IBAction func deleteMomentButton(_ sender: UIButton) {
    delegate?.deleteMoment(sourceCell: self)
  }

  var thumbFrameLayer = ThumbnailFrameLayer()

  func createFrameLayer() {
    thumbFrameLayer = ThumbnailFrameLayer(frame: bounds) // bounds.insetBy(dx: bounds.maxX*Constants.thumbnailFrameInsetPct,
                                                         //       dy: bounds.maxY*Constants.thumbnailFrameInsetPct))
    thumbFrameLayer.lineWidth = Constants.thumbnailFrameLineWidth
    thumbFrameLayer.strokeColor = FoodieGlobal.Constants.ThemeColor.cgColor
    thumbFrameView.layer.addSublayer(thumbFrameLayer)
  }
}
