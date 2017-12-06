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
  @objc optional func collectionNodeNeedsNextDataPage(for context: AnyObject?)
  
  @objc optional func collectionNodeDidEndDecelerating()
  
  @objc optional func collectionNodeDidStopScrolling()
  
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
    static let MosaicPullTranslationForChange: CGFloat = -100
    static let MosaicHighlightThresholdOffset: CGFloat = 20
    static let CarouselPullTrasnlationForBatchFetch: CGFloat = 50
  }
  
  
  
  // MARK: - Private Instance Variable
  
  private var collectionNode: ASCollectionNode
  private var allowLayoutChange: Bool
  private var allPagesFetched: Bool
  private var lastIndexPath: IndexPath?
  private var carouselBatchPending = false
  
  
  // MARK: - Public Instance Variable
  
  var delegate: FeedCollectionNodeDelegate?
  var storyArray = [FoodieStory]()
  var enableEdit = false
  
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
  
  var highlightedStoryIndex: Int? {
    
    switch layoutType {
    case .carousel:
      let layout = collectionNode.collectionViewLayout as! CarouselCollectionViewLayout
      let cardWidth = layout.itemSize.width + layout.minimumLineSpacing
      let offset = collectionNode.contentOffset.x - collectionNode.contentInset.left
      let indexPathItemNumber = Int(floor((offset - cardWidth / 2) / cardWidth) + 1)
      return toStoryIndex(from: IndexPath(item: indexPathItemNumber, section: 0))
      
    case .mosaic:
      var highlightIndexPath: IndexPath?
      var smallestPositiveMidYDifference: CGFloat = collectionNode.bounds.height - collectionNode.contentInset.top - Constants.MosaicHighlightThresholdOffset
      
      for visibleIndexPath in collectionNode.indexPathsForVisibleItems {
        guard let layoutAttributes = collectionNode.view.layoutAttributesForItem(at: visibleIndexPath) else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Cannot find Layout Attribute for item at IndexPath Section: \(visibleIndexPath.section) Row: \(visibleIndexPath.row)")
          }
          break
        }
        
        let midYDifference = layoutAttributes.frame.midY - (collectionNode.bounds.minY + collectionNode.contentInset.top + Constants.MosaicHighlightThresholdOffset)
        
        if midYDifference > 0, midYDifference < smallestPositiveMidYDifference {
          highlightIndexPath = visibleIndexPath
          smallestPositiveMidYDifference = midYDifference
        }
      }
      
      if let highlightIndexPath = highlightIndexPath {
        return toStoryIndex(from: highlightIndexPath)
      } else {
        CCLog.warning("No Highlight Index Path")
        return nil
      }
    }
  }
  
  
  
  // MARK: - Private Instance Function
  private func toIndexPath(from storyIndex: Int) -> IndexPath {
    return IndexPath(row: storyIndex, section: 0)
  }
  
  
  private func toStoryIndex(from indexPath: IndexPath) -> Int {
    return indexPath.row
  }
  
  
  private func displayStoryEntry(_ story: FoodieStory) {
    FoodieStory.setCurrentStory(to: story)
    
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryEntryViewController") as? StoryEntryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryEntryViewController Class!!")
      }
      return
    }
    
    guard let mapNavController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("No Navigation Controller or not of MapNavConveroller")
      }
      return
    }
    
    guard let moments = story.moments else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("No Moments in Story \(story.getUniqueIdentifier)")
      }
      return
    }
    
    // !!! Um... Banking on that the following operations will be quick. Don't want another spinner here...
    UIApplication.shared.beginIgnoringInteractionEvents()
    
    FoodieFetch.global.cancelAll()
    FoodieMoment.batchRetrieve(moments) { objects, error in
      if let error = error {
        AlertDialog.present(from: self, title: "Story Retrieve Failed", message: error.localizedDescription) { _ in
          CCLog.warning("batchRetrieve for Story \(story.getUniqueIdentifier) failed with error - \(error.localizedDescription)")
        }
        UIApplication.shared.endIgnoringInteractionEvents()
        return
      }
      
      story.saveDigest(to: .local, type: .draft) { error in
        if let error = error {
          AlertDialog.present(from: self, title: "Draft Save Failed", message: error.localizedDescription) { _ in
            CCLog.warning("Save of Story \(story.getUniqueIdentifier) to draft failed with error - \(error.localizedDescription)")
          }
          UIApplication.shared.endIgnoringInteractionEvents()
          return
        }
        
        DispatchQueue.main.async {
          viewController.setSlideTransition(presentTowards: .left, dismissIsInteractive: false)  // Disable Interactive Dismiss to force Discard Confirmation on Exit
          mapNavController.delegate = viewController
          viewController.workingStory = story
          viewController.restoreStoryDelegate = self
          mapNavController.pushViewController(viewController, animated: true)
          UIApplication.shared.endIgnoringInteractionEvents()
        }
      }
    }
  }
  
  
  @objc private func editStory(_ sender: TextButtonNode) {
    lastIndexPath = IndexPath(row: sender.tag, section: 0)
    let storyIndex = toStoryIndex(from: lastIndexPath!)
    let story = storyArray[storyIndex]

    if(FoodieStory.currentStory != nil) {
      // display the the discard dialog
      StorySelector.showStoryDiscardDialog(to: self) {
        FoodieStory.cleanUpDraft() { error in
          if let error = error  {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
              CCLog.assert("Error when cleaning up story draft- \(error.localizedDescription)")
            }
            return
          }
          self.displayStoryEntry(story)
        }
      }
    } else {
      displayStoryEntry(story)
    }
  }
  
  
  
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
      
      super.init(node: collectionNode)
      mosaicLayout.delegate = self
      
    case .carousel:
      collectionNode = ASCollectionNode(collectionViewLayout: CarouselCollectionViewLayout())
      collectionNode.contentInset = UIEdgeInsetsMake(0.0, contentInset, 0.0, 0.0)
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

    if storyArray.count < FoodieGlobal.Constants.StoryFeedPaginationCount {
      allPagesFetched = true
    } else {
      allPagesFetched = false
    }
    
    switch layoutType {
    case .mosaic:
      collectionNode.view.alwaysBounceHorizontal = false
      collectionNode.view.alwaysBounceVertical = true
      collectionNode.view.decelerationRate = UIScrollViewDecelerationRateNormal
      collectionNode.leadingScreensForBatching = CGFloat(FoodieGlobal.Constants.StoryFeedPaginationCount)/10.0
      
    case .carousel:
      collectionNode.view.alwaysBounceVertical = false
      collectionNode.view.alwaysBounceHorizontal = true
      collectionNode.view.decelerationRate = UIScrollViewDecelerationRateFast
      collectionNode.leadingScreensForBatching = 0.0
    }
  }

  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    collectionNode.frame = view.frame
  }
  
  
  
  // MARK: - Public Instance Function
  
  // More Data Fetched, update ColllectionNode
  func updateDataPage(withStory indexes: [Int], for context: AnyObject?, isLastPage: Bool) {
    
    // Add to Collection Node if there's any more Stories returned
    if indexes.count > 0 {
      collectionNode.insertItems(at: indexes.map { IndexPath(row: $0, section: 0) })
    }
    
    allPagesFetched = isLastPage
    context?.completeBatchFetching(true)
  }
  
  
  // If the parent view have fetched a completly different list of Stories, start from scratch
  func resetCollectionNode(with stories: [FoodieStory], completion: (() -> Void)? = nil) {
    storyArray = stories
    
    if stories.count < FoodieGlobal.Constants.StoryFeedPaginationCount {
      allPagesFetched = true
    } else {
      allPagesFetched = false
    }
    collectionNode.reloadData(completion: completion)
  }

  
  func changeLayout(to layoutType: LayoutType, animated: Bool) {
    var layout: UICollectionViewLayout
    var delegateBackup: FeedCollectionNodeDelegate?
    
    guard allowLayoutChange else {
      CCLog.warning("Layout Change is Disabled!")
      return
    }
    
    delegateBackup = delegate
    delegate = nil
    
    switch layoutType {
    case .mosaic:
      let mosaicLayout = MosaicCollectionViewLayout()
      mosaicLayout.delegate = self
      collectionNode.layoutInspector = MosaicCollectionViewLayoutInspector()
      layout = mosaicLayout
      collectionNode.leadingScreensForBatching = CGFloat(FoodieGlobal.Constants.StoryFeedPaginationCount)/10.0
      
      if let oldLayout = collectionNode.collectionViewLayout as? CarouselCollectionViewLayout {
        oldLayout.sectionInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
      }
      
    case .carousel:
      let carouselLayout = CarouselCollectionViewLayout()
      collectionNode.layoutInspector = nil
      layout = carouselLayout
      collectionNode.leadingScreensForBatching = 0.0
    }
    
    //collectionNode.collectionViewLayout.invalidateLayout()  // Don't know why this causes Carousel to Mosaic swap to crash
    collectionNode.view.setCollectionViewLayout(layout, animated: animated) { _ in
      self.collectionNode.relayoutItems()
      self.collectionNode.delegate = self
      
      switch layoutType {
      case .mosaic:
       self.collectionNode.layoutInspector = MosaicCollectionViewLayoutInspector()
        self.collectionNode.view.alwaysBounceHorizontal = false
        self.collectionNode.view.alwaysBounceVertical = true
        self.collectionNode.view.decelerationRate = UIScrollViewDecelerationRateNormal
        
        
      case .carousel:
        self.collectionNode.layoutInspector = nil
        self.collectionNode.view.alwaysBounceVertical = false
        self.collectionNode.view.alwaysBounceHorizontal = true
        self.collectionNode.view.decelerationRate = UIScrollViewDecelerationRateFast
      }
      
      self.delegate = delegateBackup
      self.delegate?.collectionNodeLayoutChanged?(to: layoutType)
    }
  }
  
  
  func scrollTo(storyIndex: Int) {
    switch layoutType {
    case .carousel:
      collectionNode.scrollToItem(at: toIndexPath(from: storyIndex), at: .centeredHorizontally, animated: true)
    case .mosaic:
      collectionNode.scrollToItem(at: toIndexPath(from: storyIndex), at: .top, animated: true)
    }
  }
  
  
  // Get an array of Story Indexes that is visible for over the threadshold percentage stated
  // If threshold is nil, all visible Story indexes will be returned no matter how little of it is visble
  // The array of Story indexes always comes sorted in decreasing percentage visible
  
  func getStoryIndexesVisible(forOver thresholdPercentage: CGFloat = 0.00) -> [Int] {
    
    var visibleStoryIndexes = [Int]()
    var visiblePercentages = [CGFloat]()
    
    for visibleIndexPath in collectionNode.indexPathsForVisibleItems {
      
      guard let layoutAttributes = collectionNode.view.layoutAttributesForItem(at: visibleIndexPath) else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("Cannot find Layout Attribute for item at IndexPath Section: \(visibleIndexPath.section) Row: \(visibleIndexPath.row)")
        }
        break
      }
      
      var percentageVisible: CGFloat!
      
      switch layoutType {
      case .carousel:
        var visibleMin = layoutAttributes.frame.minX
        var visibleMax = layoutAttributes.frame.maxX
        
        if visibleMin < collectionNode.bounds.minX {
          visibleMin = collectionNode.bounds.minX
        }
        if visibleMax > collectionNode.bounds.maxX {
          visibleMax = collectionNode.bounds.maxX
        }
        percentageVisible = (visibleMax - visibleMin) / layoutAttributes.frame.width
        
      case .mosaic:
        var visibleMin = layoutAttributes.frame.minY
        var visibleMax = layoutAttributes.frame.maxY
        
        if visibleMin < collectionNode.bounds.minY {
          visibleMin = collectionNode.bounds.minY
        }
        if visibleMax > collectionNode.bounds.maxY {
          visibleMax = collectionNode.bounds.maxY
        }
        percentageVisible = (visibleMax - visibleMin) / layoutAttributes.frame.height
      }
      
      if percentageVisible > thresholdPercentage {
        // Find where to insert this Story Index
        if let index = visiblePercentages.index(where: { $0 < percentageVisible }) {
          visibleStoryIndexes.insert(toStoryIndex(from: visibleIndexPath), at: index)
          visiblePercentages.insert(percentageVisible, at: index)
        } else {
          visibleStoryIndexes.append(toStoryIndex(from: visibleIndexPath))
          visiblePercentages.append(percentageVisible)
        }
      }
    }
    
    return visibleStoryIndexes
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
    let cellNode = FeedCollectionCellNode(story: story, edit: enableEdit)
    cellNode.layer.cornerRadius = Constants.DefaultGuestimatedCellNodeWidth * CGFloat(Constants.DefaultFeedNodeCornerRadiusFraction)
    cellNode.placeholderEnabled = true
    cellNode.backgroundColor = UIColor.lightGray
    
    // TODO: Nice to Have, shadow underneath the cards
//    cellNode.clipsToBounds = true
//
//    cellNode.layer.backgroundColor = UIColor.lightGray.cgColor
//    cellNode.layer.shadowPath = UIBezierPath(roundedRect: cellNode.bounds, cornerRadius: cellNode.cornerRadius).cgPath
//    cellNode.layer.shadowOffset = CGSize(width: 0.0, height: 8.0)
//    cellNode.layer.shadowColor = UIColor.black.cgColor
//    cellNode.layer.shadowRadius = 4.0
//    cellNode.layer.shadowOpacity = 1.0

    if enableEdit {
      guard let coverEditButton = cellNode.coverEditButton else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.fatal("Edit enabeld but coverEditButton is nil")
        }
        return { return cellNode }
      }
      coverEditButton.tag = indexPath.row
      coverEditButton.addTarget(self, action: #selector(editStory(_:)), forControlEvents: .touchUpInside)
    }
    return { return cellNode }
  }
}



// MARK: - AsyncDisplayKit Collection Delegate Protocol Conformance

extension FeedCollectionNodeController: ASCollectionDelegateFlowLayout {
  
  func collectionNode(_ collectionNode: ASCollectionNode, didSelectItemAt indexPath: IndexPath) {
    let story = storyArray[indexPath.row]
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryViewController") as? StoryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of StoryViewController Class!!")
      }
      return
    }

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
    
    // Go ahead, just display the Story~
    viewController.viewingStory = story
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
    if let delegate = delegate {
      delegate.collectionNodeNeedsNextDataPage?(for: context)
    } else {
      context.completeBatchFetching(true)
    }
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
      let maxContentOffsetX = scrollView.contentSize.width - collectionNode.bounds.width
      if !allPagesFetched, scrollView.contentOffset.x > maxContentOffsetX + Constants.CarouselPullTrasnlationForBatchFetch {
        carouselBatchPending = true
      }
      
      if carouselBatchPending, scrollView.contentOffset.x <= maxContentOffsetX {
        carouselBatchPending = false
        collectionNode.performBatch(animated: true, updates: {
          delegate?.collectionNodeNeedsNextDataPage?(for: nil)
        }, completion: nil)
      }
      
      // TODO: Add something cool in place on header pull
    }
    else {
      CCLog.fatal("Did not recognize CollectionNode Layout Type")
    }
  }
  
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    delegate?.collectionNodeDidStopScrolling?()
  }
  
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      delegate?.collectionNodeDidStopScrolling?()
    }
  }
  
  
  func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    delegate?.collectionNodeDidStopScrolling?()
  }
}



extension FeedCollectionNodeController: MosaicCollectionViewLayoutDelegate {
  internal func collectionView(_ collectionView: UICollectionView, layout: MosaicCollectionViewLayout, originalItemSizeAtIndexPath: IndexPath) -> CGSize {
    //CCLog.verbose("collectionView(:MosaicLayout:originalItemSizeAt:\(originalItemSizeAtIndexPath.item))")
    return layout.calculateConstrainedSize(for: collectionNode.bounds).max
  }
}


extension FeedCollectionNodeController: RestoreStoryDelegate {
  func updateStory(_ story: FoodieStory) {
    
    guard let lastIndexPath = lastIndexPath else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.assert("The lastIndexPath is nil. This value should have been assigned before entering edit")
      }
      return
    }
    
    storyArray[lastIndexPath.row] = story
    collectionNode.reloadItems(at: [lastIndexPath])
  }
}
