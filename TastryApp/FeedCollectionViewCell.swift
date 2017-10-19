//
//  FeedCollectionViewCell.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class FeedCollectionViewCell: UICollectionViewCell {
  
  // MARK: - Constants
  
  struct Constants {
    static let CellRoundingRadius: CGFloat = 0.0
  }
  
  
  
  // MARK: - IBOutlets
  
  @IBOutlet weak var containerView: UIView?
  @IBOutlet weak var storyButton: UIButton?
  @IBOutlet weak var storyTitle: UILabel?
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
  
  
  
  // MARK: - Private Instance Variable
  func prefetch(for story: FoodieStory) {
    let storyRecursivePrefetchOperation = StoryOperation.createRecursive(on: story, at: .low)
    FoodieFetch.global.queue(storyRecursivePrefetchOperation, at: .low)
  }
  
  func cancelPrefetch(for story: FoodieStory) {
    FoodieFetch.global.cancel(for: story, at: .low)
  }
  
  
  
  // MARK: - Public Instance Variables
  
  var cellRoundingRadius = Constants.CellRoundingRadius
  var cellStatusMutex = SwiftMutex.create()
  
  var cellStory: FoodieStory? {
    willSet {
      if let story = cellStory, newValue == nil {
        cancelPrefetch(for: story)
      }
    }
    didSet {
      if let story = cellStory, cellDisplayed == true {
        prefetch(for: story)
      }
    }
  }
  
  var cellDisplayed = false {
    didSet {
      if let story = cellStory, cellDisplayed == true {
        prefetch(for: story)
      }
      else if let story = cellStory, cellDisplayed == false, oldValue == true {
        cancelPrefetch(for: story)
      }
    }
  }
  
  
  
  // MARK: - Public Instance Functions
  
  override func awakeFromNib() {
    super.awakeFromNib()
    if cellRoundingRadius > 0.0 {
      containerView?.layer.cornerRadius = cellRoundingRadius
      containerView?.layer.masksToBounds = true
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cellStory = nil
    cellDisplayed = false
    storyTitle?.text = ""
    storyButton?.setImage(nil, for: .normal)
    storyButton?.removeTarget(nil, action: nil, for: .allEvents)
  }
}
