//
//  FeedCollectionViewCell.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class FeedCollectionViewCell: UICollectionViewCell {
  @IBOutlet weak var journalButton: UIButton!
  @IBOutlet weak var journalTitle: UILabel!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  var cellStatusMutex = SwiftMutex.create()
  var cellLoaded = false
  var cellDisplayed = false
  
  override func prepareForReuse() {
    super.prepareForReuse()
    journalButton?.setImage(nil, for: .normal)
    journalButton?.removeTarget(nil, action: nil, for: .allEvents)
  }
}
