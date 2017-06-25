//
//  FeedCollectionViewCell.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import UIKit

class FeedCollectionViewCell: UICollectionViewCell {
  @IBOutlet weak var journalButton: UIButton!
  @IBOutlet weak var journalTitle: UILabel!
  
  var cellStatusMutex = pthread_mutex_t()
  var cellLoaded = false
  var cellDisplayed = false
  
  override func prepareForReuse() {
    super.prepareForReuse()
    journalButton?.setImage(nil, for: .normal)
    journalButton?.removeTarget(nil, action: nil, for: .allEvents)
  }
}
