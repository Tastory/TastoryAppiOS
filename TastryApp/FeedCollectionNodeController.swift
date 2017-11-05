//
//  FeedCollectionNodeController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-28.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation
import AsyncDisplayKit

final class FeedCollectionNodeController: ASViewController<ASCollectionNode> {
  
  // MARK: - Private Class Constants
  private struct Constants {
    static let DefaultColumns: Int = 2
    static let DefaultFeedNodeMargin: CGFloat = 5.0
    static let DefaultCoverPhotoAspecRatio = FoodieGlobal.Constants.DefaultMomentAspectRatio
    static let DefaultFeedNodeCornerRadiusFraction = 0.05
  }
  
  
  
  // MARK: - Public Instance Variable
  var storyQuery: FoodieQuery!
  var storyArray = [FoodieStory]()
  
  
  
  // MARK: - Private Instance Variable
  private var flowLayout: UICollectionViewFlowLayout
  private var collectionNode: ASCollectionNode
  private var numOfColumns = Constants.DefaultColumns
  private var feedNodeMargin = Constants.DefaultFeedNodeMargin
  private var itemWidth: CGFloat
  private var itemHeight: CGFloat
  
  // MARK: - Public Instance Function
  init() {
    flowLayout = UICollectionViewFlowLayout()
    
    // For ASCollectionNode, it gets the Cell Constraint size via the itemSize property of the Layout via a Layout Inspector
    let screenWidth = UIScreen.main.bounds.width
    itemWidth = (screenWidth - 2*feedNodeMargin - CGFloat(numOfColumns - 1)*feedNodeMargin) / CGFloat(numOfColumns)
    if numOfColumns == 3 { itemWidth = floor(itemWidth) }  // Weird problem when the itemWidth is .3 repeat.
    itemHeight = itemWidth/Constants.DefaultCoverPhotoAspecRatio
    
    flowLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
    flowLayout.estimatedItemSize = CGSize(width: itemWidth, height: itemHeight)
    flowLayout.sectionInset = UIEdgeInsetsMake(0.0, feedNodeMargin, 0.0, feedNodeMargin)
    flowLayout.minimumInteritemSpacing = feedNodeMargin
    flowLayout.minimumLineSpacing = feedNodeMargin
    
    collectionNode = ASCollectionNode(collectionViewLayout: flowLayout)

    super.init(node: collectionNode)
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    CCLog.fatal("AsyncDisplayKit is incompatible with Storyboards")
  }
  
  
  
  // MARK: - Node Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    collectionNode.frame = view.bounds
    collectionNode.delegate = self
    collectionNode.dataSource = self
  }
}



// MARK: - AsyncDisplayKit Collection Data Source Protocol Conformance

extension FeedCollectionNodeController: ASCollectionDataSource {

  func numberOfSections(in collectionNode: ASCollectionNode) -> Int {
    return 1
  }
  

  func collectionNode(_ collectionNode: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
    return storyArray.count
  }
  

  func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
    let story = storyArray[indexPath.row]
    let cellNode = FeedCollectionCellNode(story: story)
    cellNode.cornerRadius = itemWidth * CGFloat(Constants.DefaultFeedNodeCornerRadiusFraction)
    return { return cellNode }
  }
}



// MARK: - AsyncDisplayKit Collection Delegate Protocol Conformance

extension FeedCollectionNodeController: ASCollectionDelegate {
  
  func collectionNode(_ collectionNode: ASCollectionNode, didSelectItemAt indexPath: IndexPath) {
    let story = storyArray[indexPath.row]
    // Stop all prefetches but the story being viewed
    FoodieFetch.global.cancelAllBut(for: story)
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryViewController") as? StoryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryViewController Class!!")
      }
      return
    }
    viewController.viewingStory = story
    viewController.setTransition(presentTowards: .up, dismissTowards: .down, dismissIsDraggable: true, dragDirectionIsFixed: true)
    self.present(viewController, animated: true)
  }
}
