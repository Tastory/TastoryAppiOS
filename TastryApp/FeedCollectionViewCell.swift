//
//  FeedCollectionViewCell.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class FeedCollectionViewCell: UICollectionViewCell {
  
  struct Constants {
    static let CellRoundingRadius: CGFloat = 0.0
  }
  
  @IBOutlet weak var containerView: UIView!
  @IBOutlet weak var storyButton: UIButton!
  @IBOutlet weak var storyTitle: UILabel!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  var cellStatusMutex = SwiftMutex.create()
  var cellLoaded = false
  var cellDisplayed = false
  var cellRoundingRadius = Constants.CellRoundingRadius
  
  override func awakeFromNib() {
    super.awakeFromNib()
    if cellRoundingRadius > 0.0 {
      containerView.layer.cornerRadius = cellRoundingRadius
      containerView.layer.masksToBounds = true
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    storyButton?.setImage(nil, for: .normal)
    storyButton?.removeTarget(nil, action: nil, for: .allEvents)
  }
}
