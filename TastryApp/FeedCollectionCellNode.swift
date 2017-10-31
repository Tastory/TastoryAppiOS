//
//  FeedCollectionCellNode.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-28.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation
import AsyncDisplayKit

class FeedCollectionCellNode: ASCellNode {
  
  private var storyCoverImageNode: ASNetworkImageNode!
  private var storyTitleLabel : ASTextNode!
  
  
  @objc private func viewStory(_ sender: UIButton) {
    let story = storyArray[sender.tag]
    // Stop all prefetches but the story being viewed
    FoodieFetch.global.cancelAllBut(for: story)
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryViewController") as? StoryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryViewController Class!!")
      }
      return
    }
    viewController.viewingStory = storyArray[sender.tag]
    viewController.setTransition(presentTowards: .up, dismissTowards: .down, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
  }
  
  
  init(story: FoodieStory) {
    super.init()
    
    guard let thumbnailFileName = story.thumbnailFileName else {
      CCLog.fatal("No Thumbnail Filename in Story \(story.getUniqueIdentifier())")
    }
    
    storyCoverImageNode = ASNetworkImageNode()
    storyCoverImageNode.url = FoodieFileObject.getS3URL(for: thumbnailFileName)
    storyTitleLabel = ASTextNode()
  }
  
  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    <#code#>
  }
}
