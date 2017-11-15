//
//  FeedCollectionNodeController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-28.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation
import AsyncDisplayKit


@objc protocol FeedCollectionNodeDelegate {
  
  // FeedCollectionNodeController needs more data
  @objc optional func collectionNodeNeedsNextDataPage(for context: AnyObject)
  
  @objc optional func collectionNodeDidEndDecelerating()
  
  @objc optional func collectionNodeScrollViewDidEndDragging()
  
  @objc optional func collectionNodeLayoutChanged(to layoutType: FeedCollectionNodeController.LayoutType)
}



final class FeedCollectionNodeController: ASViewController<ASCollectionNode> {
  
  
  // MARK: - Types and Enumeration
  
  @objc enum LayoutType: Int {
    case mosaic
    case carousel
  }
  
  
  // MARK: - Private Class Constants
  
  private struct Constants {
    
    static let DefaultGuestimatedCellNodeWidth: CGFloat = 150.0
    static let DefaultFeedNodeCornerRadiusFraction:CGFloat = 0.05
    static let MosaicPullTranslationForChange: CGFloat = -80
    static let MosaicHighlightThresholdPoints: CGFloat = 8.0
  }
  
  
  
  // MARK: - Public Instance Variable
  
  var delegate: FeedCollectionNodeDelegate?
  var storyArray = [FoodieStory]()
  
  var layoutType: LayoutType {
    if collectionNode.collectionViewLayout is CarouselCollectionViewLayout {
      return .carousel
    }
    else if collectionNode.collectionViewLayout is MosaicCollectionViewLayout {
      return .mosaic
    }
    else {
      CCLog.fatal("Did not recognize CollectionNode Layout Type")
    }
  }
  
  var highlightedStoryIndex: Int {
    
    if let layout = collectionNode.collectionViewLayout as? CarouselCollectionViewLayout {
      
      let cardWidth = layout.itemSize.width + layout.minimumLineSpacing
      let offset = collectionNode.contentOffset.x
      let indexPathItemNumber = Int(floor((offset - cardWidth / 2) / cardWidth) + 1)
      return toStoryIndex(from: IndexPath(item: indexPathItemNumber, section: 0))
      
    } else if collectionNode.collectionViewLayout is MosaicCollectionViewLayout {
    
      var highlightIndexPath: IndexPath?
      var smallestPositiveMidYDifference: CGFloat = collectionNode.bounds.height
      
      for visibleIndexPath in collectionNode.indexPathsForVisibleItems {
        guard let layoutAttributes = collectionNode.view.layoutAttributesForItem(at: visibleIndexPath) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Cannot find Layout Attribute for item at IndexPath Section: \(visibleIndexPath.section) Row: \(visibleIndexPath.row)")
          }
          break
        }
        
        let midYDifference = layoutAttributes.frame.midY - collectionNode.bounds.minY
        
        if midYDifference > 0, midYDifference < smallestPositiveMidYDifference {
          highlightIndexPath = visibleIndexPath
          smallestPositiveMidYDifference = midYDifference
        }
      }
      
      if let highlightIndexPath = highlightIndexPath {
        return toStoryIndex(from: highlightIndexPath)
      } else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("No Highlight Index Path")
        }
        return 0
      }
    } else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.fatal("Did not recognize CollectionNode Layout Type")
      }
      return 0
    }
  }
  
//  var fullyVisibleStoryIndexes
//  var visibleStoryIndexes
  
  
  
  // MARK: - Private Instance Variable
  
  private var collectionNode: ASCollectionNode
  private var allowLayoutChange: Bool
  private var allPagesFetched: Bool
  
  
  
  // MARK: - Node Controller Lifecycle
  
  init(with layoutType: LayoutType,
       offsetBy contentInset: CGFloat = 0.0,
       allowLayoutChange: Bool,
       adjustScrollViewInset: Bool) {
    
    self.allowLayoutChange = allowLayoutChange
    self.allPagesFetched = false
    
    switch layoutType {
    case .mosaic:
      let mosaicLayout = MosaicCollectionViewLayout()
      collectionNode = ASCollectionNode(collectionViewLayout: mosaicLayout)
      collectionNode.layoutInspector = MosaicCollectionViewLayoutInspector()
      
      if contentInset > 0 {
        collectionNode.contentInset = UIEdgeInsetsMake(contentInset + MosaicCollectionViewLayout.Constants.DefaultFeedNodeMargin, 0.0, 0.0, 0.0)
      } else {
        collectionNode.contentInset = UIEdgeInsetsMake(contentInset, 0.0, 0.0, 0.0)
      }
      
      // The CollectionView need to bounce even if there's not enough item to fill the view, otherwise user cannot transition to Carousel Layout
      // Might want to disable this and all bounce for better Animated Transitioning?
      collectionNode.view.alwaysBounceVertical = true
      collectionNode.view.alwaysBounceHorizontal = false
      super.init(node: collectionNode)
      mosaicLayout.delegate = self
      
    case .carousel:
      collectionNode = ASCollectionNode(collectionViewLayout: CarouselCollectionViewLayout())
      collectionNode.contentInset = UIEdgeInsetsMake(0.0, contentInset, 0.0, 0.0)
      
      collectionNode.view.alwaysBounceVertical = false
      collectionNode.view.alwaysBounceHorizontal = true
      super.init(node: collectionNode)
    }
    
    node.backgroundColor = .clear
    collectionNode.delegate = self
    collectionNode.dataSource = self
    collectionNode.view.isDirectionalLockEnabled = true
    automaticallyAdjustsScrollViewInsets = adjustScrollViewInset
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    CCLog.fatal("AsyncDisplayKit is incompatible with Storyboards")
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    collectionNode.frame = view.bounds
  }

  
  
  // MARK: - Private Instance Function
  private func toIndexPath(from storyIndex: Int) -> IndexPath {
    return IndexPath(row: storyIndex, section: 0)
  }
  
  private func toStoryIndex(from indexPath: IndexPath) -> Int {
    return indexPath.row
  }
  
  
  
  // MARK: - Public Instance Function
  
  // More Data Fetched, update ColllectionNode
  func updateDataPage(withStory indexes: [Int], for context: AnyObject, isLastPage: Bool) {
    
    guard let batchContext = context as? ASBatchContext else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Expected context of type ASBatchContext")
      }
      return
    }
    
    // Add to Collection Node if there's any more Stories returned
    if indexes.count > 0 {
      collectionNode.insertItems(at: indexes.map { IndexPath.init(row: $0, section: 1) })
    }
    
    allPagesFetched = isLastPage
    batchContext.completeBatchFetching(true)
  }
  
  
  // If the parent view have fetched a completly different list of Stories, start from scratch
  func resetCollectionNode(with stories: [FoodieStory], completion: (() -> Void)? = nil) {
    storyArray = stories
    allPagesFetched = false
    collectionNode.reloadData(completion: completion)
  }

  
  func changeLayout(to layoutType: LayoutType, animated: Bool) {
    var layout: UICollectionViewLayout
    
    guard allowLayoutChange else {
      CCLog.warning("Layout Change is Disabled!")
      return
    }
    
    switch layoutType {
    case .mosaic:
      let mosaicLayout = MosaicCollectionViewLayout()
      mosaicLayout.delegate = self
      collectionNode.layoutInspector = MosaicCollectionViewLayoutInspector()
      // The CollectionView need to bounce even if there's not enough item to fill the view, otherwise user cannot transition to Carousel Layout
      // Might want to disable this and all bounce for better Animated Transitioning?
      collectionNode.view.alwaysBounceVertical = true
      collectionNode.view.alwaysBounceHorizontal = false
      layout = mosaicLayout
      
      if let oldLayout = collectionNode.collectionViewLayout as? CarouselCollectionViewLayout {
        oldLayout.sectionInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
      }
      
    case .carousel:
      let carouselLayout = CarouselCollectionViewLayout()
      collectionNode.layoutInspector = nil
      collectionNode.view.alwaysBounceVertical = false
      collectionNode.view.alwaysBounceHorizontal = true
      layout = carouselLayout
    }
    
    //collectionNode.collectionViewLayout.invalidateLayout()  // Don't know why this causes Carousel to Mosaic swap to crash
    collectionNode.view.setCollectionViewLayout(layout, animated: animated)
    collectionNode.relayoutItems()
    collectionNode.delegate = self
    
    delegate?.collectionNodeLayoutChanged?(to: layoutType)
  }
  
  
  func scrollTo(storyIndex: Int) {
    switch layoutType {
    case .carousel:
      collectionNode.scrollToItem(at: toIndexPath(from: storyIndex), at: .centeredHorizontally, animated: true)
    case .mosaic:
      collectionNode.scrollToItem(at: toIndexPath(from: storyIndex), at: .top, animated: true)
    }
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
    cellNode.cornerRadius = Constants.DefaultGuestimatedCellNodeWidth * CGFloat(Constants.DefaultFeedNodeCornerRadiusFraction)
    cellNode.backgroundColor = UIColor.gray
    cellNode.placeholderEnabled = true
    return { return cellNode }
  }
}



// MARK: - AsyncDisplayKit Collection Delegate Protocol Conformance

extension FeedCollectionNodeController: ASCollectionDelegateFlowLayout {
  
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

    guard let popFromNode = collectionNode.nodeForItem(at: indexPath) else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("No Feed Collection Node for Index Path?")
      }
      return
    }
    
    guard let mapNavController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("No Navigation Controller or not of MapNavConveroller")
      }
      return
    }
    
    viewController.setPopTransition(popFrom: popFromNode.view, withBgOverlay: true, dismissIsInteractive: true)
    mapNavController.delegate = viewController
    mapNavController.pushViewController(viewController, animated: true)
    
    // Scroll the selected story to top to make sure it's not off bounds to reduce animation artifact
    guard let layoutAttributes = collectionNode.view.layoutAttributesForItem(at: indexPath) else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Cannot find Layout Attribute for item at IndexPath Section: \(indexPath.section) Row: \(indexPath.row)")
      }
      return
    }
    
    if layoutAttributes.frame.minY < collectionNode.bounds.minY {
      collectionNode.scrollToItem(at: indexPath, at: .top, animated: true)
    } else if layoutAttributes.frame.maxY > collectionNode.bounds.maxY {
      collectionNode.scrollToItem(at: indexPath, at: .bottom, animated: true)
    }
    
    if layoutAttributes.frame.minX < collectionNode.bounds.minX {
      collectionNode.scrollToItem(at: indexPath, at: .left, animated: true)
    } else if layoutAttributes.frame.maxX > collectionNode.bounds.maxX {
      collectionNode.scrollToItem(at: indexPath, at: .right, animated: true)
    }
  }
  
  
  func shouldBatchFetch(for collectionNode: ASCollectionNode) -> Bool {
    return !allPagesFetched
  }
  
  
  func collectionNode(_ collectionNode: ASCollectionNode, willBeginBatchFetchWith context: ASBatchContext) {
    delegate?.collectionNodeNeedsNextDataPage?(for: context)
  }
  
  
  func collectionNode(_ collectionNode: ASCollectionNode, constrainedSizeForItemAt indexPath: IndexPath) -> ASSizeRange {
    if let layout = collectionNode.collectionViewLayout as? MosaicCollectionViewLayout {
      //CCLog.verbose(":collectionView(:MosaicLayout:constrainedSizeForItemAt\(indexPath.item))")
      return layout.calculateConstrainedSize(for: collectionNode.bounds)
    }
    else if let layout = collectionNode.collectionViewLayout as? CarouselCollectionViewLayout {
      //CCLog.verbose(":collectionView(:CarouselLayout:constrainedSizeForItemAt\(indexPath.item))")
      return layout.calculateConstrainedSize(for: collectionNode.bounds)
    }
    else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.fatal("Did not recognize CollectionNode Layout Type")
      }
      return ASSizeRangeZero
    }
  }
  
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    if let layout = collectionViewLayout as? MosaicCollectionViewLayout {
      return layout.calculateSectionInset(for: collectionView.bounds, at: section)
    }
    else if let layout = collectionViewLayout as? CarouselCollectionViewLayout {
      return layout.calculateSectionInset(for: collectionView.bounds, at: section)
    }
    else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.fatal("Did not recognize CollectionNode Layout Type")
      }
      return UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
    }
  }
  
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if collectionNode.collectionViewLayout is MosaicCollectionViewLayout {
      if scrollView.contentOffset.y < Constants.MosaicPullTranslationForChange {
        changeLayout(to: .carousel, animated: true)
      }
    }
    else if collectionNode.collectionViewLayout is CarouselCollectionViewLayout {
      // TODO: Add something cool in place + Pull to Refresh
    }
    else {
      CCLog.fatal("Did not recognize CollectionNode Layout Type")
    }
  }
  
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    delegate?.collectionNodeDidEndDecelerating?()
  }
  
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    delegate?.collectionNodeScrollViewDidEndDragging?()
  }
  
}



extension FeedCollectionNodeController: MosaicCollectionViewLayoutDelegate {
  internal func collectionView(_ collectionView: UICollectionView, layout: MosaicCollectionViewLayout, originalItemSizeAtIndexPath: IndexPath) -> CGSize {
    //CCLog.verbose("collectionView(:MosaicLayout:originalItemSizeAt:\(originalItemSizeAtIndexPath.item))")
    return layout.calculateConstrainedSize(for: collectionNode.bounds).max
  }
}
