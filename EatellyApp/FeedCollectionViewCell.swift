//
//  FeedCollectionViewCell.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class FeedCollectionViewCell: UICollectionViewCell {
  @IBOutlet weak var storyButton: UIButton!
  @IBOutlet weak var storyTitle: UILabel!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  var cellStatusMutex = SwiftMutex.create()
  var cellLoaded = false
  var cellDisplayed = false
  
  override func prepareForReuse() {
    super.prepareForReuse()
    storyButton?.setImage(nil, for: .normal)
    storyButton?.removeTarget(nil, action: nil, for: .allEvents)
  }
}
