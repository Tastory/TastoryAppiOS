//
//  FeedCollectionNodeController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-10-28.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import Foundation
import AsyncDisplayKit


@objc protocol FeedCollectionNodeDelegate: class {
  
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
    static let MosaicHighlightThresholdOffset: CGFloat = 80
    static let CarouselPullTrasnlationForBatchFetch: CGFloat = 50
    static let SelectionFrameWidth: CGFloat = 2.0
    static let SelectionFrameColor: CGColor = UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.7).cgColor
  }
  
  
  
  // MARK: - Private Instance Variable
  
  private let mosaicLayoutInspector = MosaicCollectionViewLayoutInspector()
  private var collectionNode: ASCollectionNode
  private var allowLayoutChange: Bool
  private var allPagesFetched: Bool
  private var lastIndexPath: IndexPath?
  private var carouselBatchPending = false
  private var lastScrollIndex: Int?
  
  // MARK: - Public Instance Variable
  
  weak var delegate: FeedCollectionNodeDelegate?
  var deepLinkStoryId: String?
  var storyArray = [FoodieStory]()
  var enableEdit = false
  var roundMosaicTop = false
  
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
  
  var selectedStoryIndex: Int?
  var selectedLayer: CALayer?
  
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
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
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
  private func displayStoryIfDeepLink() {
    if deepLinkStoryId != nil {

      
      guard let storyIdx = lastScrollIndex else {

        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("highlightedStoryIndex is nil")
        }
        UIApplication.shared.endIgnoringInteractionEvents()
        return
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + FoodieGlobal.Constants.DefaultDeepLinkWaitDelay) { [weak self] in
        self?.displayStory(didSelectItemAt: IndexPath(item: storyIdx, section: 0))
      }
    }
  }

  private func toIndexPath(from storyIndex: Int) -> IndexPath {
    return IndexPath(row: storyIndex, section: 0)
  }
  
  
  private func toStoryIndex(from indexPath: IndexPath) -> Int {
    return indexPath.row
  }
  
  
  private func displayStoryEntry(_ story: FoodieStory) {
    FoodieStory.setCurrentStory(to: story)
    
    guard let moments = story.moments else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Moments in Story \(story.getUniqueIdentifier)")
      }
      return
    }
    
    // !!! Um... Banking on that the following operations will be quick. Don't want another spinner here...
    UIApplication.shared.beginIgnoringInteractionEvents()

    FoodieFetch.global.cancelAll()
    
    let batchRetrieving = FoodieMoment.batchRetrieve(moments) { objects, error in
      if let error = error {
        AlertDialog.present(from: self, title: "Story Retrieve Failed", message: error.localizedDescription) { _ in
          CCLog.warning("batchRetrieve for Story \(story.getUniqueIdentifier) failed with error - \(error.localizedDescription)")
        }
        UIApplication.shared.endIgnoringInteractionEvents()
        return
      }
      
      self.saveDraftAndPresentEntry(for: story)
    }
    
    if batchRetrieving { return }
      
    else {
      saveDraftAndPresentEntry(for: story)
    }
  }
  
  
  private func saveDraftAndPresentEntry(for story: FoodieStory) {
    
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryEntryViewController") as? StoryEntryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of StoryEntryViewController Class!!")
      }
      return
    }
    
    guard let mapNavController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Navigation Controller or not of MapNavConveroller")
      }
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
        mapNavController.pushViewController(viewController, animated: true)
        UIApplication.shared.endIgnoringInteractionEvents()
      }
    }
  }
  
  
  private func displayStory(didSelectItemAt indexPath: IndexPath) {
    
    if deepLinkStoryId != nil {
      deepLinkStoryId = nil
      UIApplication.shared.endIgnoringInteractionEvents()
      DeepLink.clearDeepLinkInfo()
    }
    
    let storyIndex = toStoryIndex(from: indexPath)
    let story = storyArray[storyIndex]
    
    CCLog.info("User didSelect Story Index \(storyIndex)")
    
    // Analytics
    let isOwnStory = story.author == FoodieUser.current
    var launchType: Analytics.StoryLaunchType
    
    // Determine the Launch Type
    switch layoutType {
    case .carousel:
      launchType = .carousel
    case .mosaic:
      if allowLayoutChange {
        launchType = .mosaic
      } else {
        launchType = .profile
      }
    }
    
    if isOwnStory {
      Analytics.logStoryOwnViewEvent(username: FoodieUser.current?.username ?? "nil", launchType: launchType)
    } else if let moments = story.moments, moments.count > 0 {
      
      if story.objectId == nil { CCLog.assert("Story object ID should never be nil") }
      if story.title == nil { CCLog.assert("Story Title should never be nil")}
      if story.author?.username == nil { CCLog.assert("Story Author & Username should never be nil")}
      
      Analytics.logStoryViewEvent(username: FoodieUser.current?.username ?? "nil",
                                  storyId: story.objectId ?? "",
                                  name: story.title ?? "",
                                  authorName: story.author?.username ?? "",
                                  launchType: launchType,
                                  totalMoments: moments.count)
    }
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "StoryViewController") as? StoryViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of StoryViewController Class!!")
      }
      return
    }
    
    guard let popFromNode = collectionNode.nodeForItem(at: indexPath) else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Feed Collection Node for Index Path?")
      }
      return
    }
    
    guard let mapNavController = navigationController as? MapNavController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("No Navigation Controller or not of MapNavConveroller")
      }
      return
    }
    
    // Scroll the selected story to top to make sure it's not off bounds to reduce animation artifact
    guard let layoutAttributes = collectionNode.view.layoutAttributesForItem(at: indexPath) else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("Cannot find Layout Attribute for item at IndexPath Section: \(indexPath.section) Row: \(indexPath.row)")
      }
      return
    }
    
    // Go ahead, just display the Story~
    viewController.viewingStory = story
    let transitionDuration = viewController.setPopTransition(popFrom: popFromNode.view, withBgOverlay: true, dismissIsInteractive: true)
    mapNavController.delegate = viewController
    mapNavController.pushViewController(viewController, animated: true)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration.magnitude) {
      
      // Vertical direction adjustment
      let topAdjustment = max(self.collectionNode.contentInset.top, 0)
      let bottomAdjustment = max(self.collectionNode.contentInset.bottom, 0)
      
      if layoutAttributes.frame.minY < (self.collectionNode.bounds.minY + topAdjustment) {
        self.collectionNode.scrollToItem(at: indexPath, at: .top, animated: false)
      } else if layoutAttributes.frame.maxY > (self.collectionNode.bounds.maxY - bottomAdjustment) {
        self.collectionNode.scrollToItem(at: indexPath, at: .bottom, animated: false)
      }
      
      // Horizontal direction adjustment
      //      let leftAdjustment = max(self.collectionNode.contentInset.left, 0)
      //      let rightAdjustment = max(self.collectionNode.contentInset.right, 0)
      //
      //      if layoutAttributes.frame.minX < (self.collectionNode.bounds.minX + leftAdjustment) {
      //        self.collectionNode.scrollToItem(at: indexPath, at: .left, animated: false)
      //      } else if layoutAttributes.frame.maxX > (self.collectionNode.bounds.maxX - rightAdjustment) {
      //        self.collectionNode.scrollToItem(at: indexPath, at: .right, animated: false)
      //      }
    }
  }
  
  
  @objc private func editStory(_ sender: ImageButtonNode) {
    lastIndexPath = IndexPath(row: sender.tag, section: 0)
    let storyIndex = toStoryIndex(from: lastIndexPath!)
    let story = storyArray[storyIndex]

    if(FoodieStory.currentStory != nil) {
      // display the the discard dialog
      ConfirmationDialog.showStoryDiscardDialog(to: self) {
        FoodieStory.cleanUpDraft() { error in
          if let error = error  {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
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
      collectionNode.layoutInspector = mosaicLayoutInspector
      
      if contentInset > 0 {
        collectionNode.contentInset = UIEdgeInsets.init(top: contentInset + MosaicCollectionViewLayout.Constants.DefaultFeedNodeMargin, left: 0.0, bottom: 0.0, right: 0.0)
      } else {
        collectionNode.contentInset = UIEdgeInsets.init(top: contentInset, left: 0.0, bottom: 0.0, right: 0.0)
      }
      
      super.init(node: collectionNode)
      mosaicLayout.delegate = self
      
    case .carousel:
      collectionNode = ASCollectionNode(collectionViewLayout: CarouselCollectionViewLayout())
      collectionNode.contentInset = UIEdgeInsets.init(top: 0.0, left: contentInset, bottom: 0.0, right: 0.0)
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

    self.view.accessibilityIdentifier = "feedCollectionNode"

    if storyArray.count < FoodieGlobal.Constants.StoryFeedPaginationCount {
      allPagesFetched = true
    } else {
      allPagesFetched = false
    }
    
    switch layoutType {
    case .mosaic:
      collectionNode.view.alwaysBounceHorizontal = false
      collectionNode.view.alwaysBounceVertical = true
      collectionNode.view.decelerationRate = UIScrollView.DecelerationRate.normal
      collectionNode.leadingScreensForBatching = CGFloat(FoodieGlobal.Constants.StoryFeedPaginationCount)/10.0

    case .carousel:
      collectionNode.view.alwaysBounceVertical = false
      collectionNode.view.alwaysBounceHorizontal = true
      collectionNode.view.decelerationRate = UIScrollView.DecelerationRate.fast
      collectionNode.leadingScreensForBatching = 0.0
    }
  }


  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if roundMosaicTop && layoutType == .mosaic {
      
      let collectionWidth = collectionNode.view.bounds.width
      let collectionHeight = collectionNode.view.bounds.height
      let numOfColumns = MosaicCollectionViewLayout.Constants.DefaultColumns
      let columnMargin = MosaicCollectionViewLayout.Constants.DefaultFeedNodeMargin
      let columnWidth = MosaicCollectionViewLayout.defaultColumnWidth(for: collectionWidth)
      let cornerRadii = Constants.DefaultGuestimatedCellNodeWidth * CGFloat(Constants.DefaultFeedNodeCornerRadiusFraction)
      let shapeLayerPath = UIBezierPath()

      for columnNumber in 0..<numOfColumns {

        let roundedRect = CGRect(x: CGFloat(columnNumber)*columnWidth + CGFloat(columnNumber+1)*columnMargin, y: 0.0, width: columnWidth, height: collectionHeight)
        let cornerSize = CGSize(width: cornerRadii, height: cornerRadii)
        let roundedPath = UIBezierPath(roundedRect: roundedRect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: cornerSize)

        shapeLayerPath.append(roundedPath)
      }

      let rectPath = UIBezierPath(rect: CGRect(x: 0.0, y: cornerRadii + 1.0, width: collectionWidth, height: collectionHeight - cornerRadii - 1.0))
      shapeLayerPath.append(rectPath)


      let maskLayer = CAShapeLayer()
      maskLayer.frame = collectionNode.view.bounds
      maskLayer.path = shapeLayerPath.cgPath
      maskLayer.lineWidth = 0.0
      maskLayer.strokeColor = UIColor.black.cgColor
      maskLayer.fillColor = UIColor.black.cgColor

      collectionNode.layer.mask = maskLayer
      
//      let gradientLayer = CAGradientLayer()
//      gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
//      gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
//      gradientLayer.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
//      gradientLayer.locations = [0.0, 0.90, 1.0]
//      gradientLayer.frame = collectionNode.bounds
//
//      collectionNode.layer.mask = gradientLayer
    } else {
      collectionNode.layer.mask = nil
    }
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if deepLinkStoryId != nil {
      UIApplication.shared.beginIgnoringInteractionEvents()
    }
  }

  // MARK: - Public Instance Function
  func processDeepLinkStoryIfAvail() {
    if let storyId = deepLinkStoryId{
      // check appdelegate if deeplink is used
      for story in storyArray  {
        if story.objectId == storyId {

          guard let storyIdx = storyArray.index(of: story) else {
            AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
              CCLog.fatal("Can't determined story index")
            }
            UIApplication.shared.endIgnoringInteractionEvents()
            return
          }

          DispatchQueue.main.asyncAfter(deadline: .now() + FoodieGlobal.Constants.DefaultDeepLinkWaitDelay) { [weak self] in
            // story with index 0 or 1 doesn't activate any scrolling so we need to manually show the stories
            // scrolling occurs when index is above 1 and after the scrolling is completed, the deeplink content is displayed
            if storyIdx == 0 || storyIdx == 1 {
              self?.displayStory(didSelectItemAt: IndexPath(row: storyIdx, section: 0))
            } else {
              self?.collectionNode.scrollToItem(at: IndexPath(row: storyIdx, section: 0), at: .top, animated: true)
              self?.lastScrollIndex = storyIdx
            }
          }
        }
      }
      // make sure interaction resumes in case we dont find the story
      UIApplication.shared.endIgnoringInteractionEvents()
    }
  }


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
      collectionNode.layoutInspector = mosaicLayoutInspector
      layout = mosaicLayout
      collectionNode.leadingScreensForBatching = CGFloat(FoodieGlobal.Constants.StoryFeedPaginationCount)/10.0
      
      if let oldLayout = collectionNode.collectionViewLayout as? CarouselCollectionViewLayout {
        oldLayout.sectionInset = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
      }
      
    case .carousel:
      let carouselLayout = CarouselCollectionViewLayout()
      collectionNode.layoutInspector = nil
      layout = carouselLayout
      collectionNode.leadingScreensForBatching = 0.0
    }
    
    //collectionNode.collectionViewLayout.invalidateLayout()  // Don't know why this causes Carousel to Mosaic swap to crash
    collectionNode.view.setCollectionViewLayout(layout, animated: animated) { [unowned self] _ in
      self.collectionNode.relayoutItems()
      self.collectionNode.delegate = self
      
      switch layoutType {
      case .mosaic:
       self.collectionNode.layoutInspector = self.mosaicLayoutInspector
        self.collectionNode.view.alwaysBounceHorizontal = false
        self.collectionNode.view.alwaysBounceVertical = true
        self.collectionNode.view.decelerationRate = UIScrollView.DecelerationRate.normal
        
        
      case .carousel:
        self.collectionNode.layoutInspector = nil
        self.collectionNode.view.alwaysBounceVertical = false
        self.collectionNode.view.alwaysBounceHorizontal = true
        self.collectionNode.view.decelerationRate = UIScrollView.DecelerationRate.fast
      }
      
      self.delegate = delegateBackup
      self.delegate?.collectionNodeLayoutChanged?(to: layoutType)
    }
  }
  
  
  var scrollPoint: CGPoint?
  var endPoint: CGPoint?
  var scrollTimer: Timer?
  var scrollingUp = false
  var scrollCompletion: (()->())?
  
  func scrollToIndexPath(path: IndexPath, completion: (()->())? = nil) {
    let atts = collectionNode.view.layoutAttributesForItem(at: path)
    endPoint = CGPoint(x: 0, y: atts!.frame.origin.y - collectionNode.contentInset.top)
    scrollPoint = collectionNode.contentOffset
    scrollingUp = collectionNode.contentOffset.y > self.endPoint!.y
    scrollCompletion = completion
    
    scrollTimer?.invalidate()
    scrollTimer = Timer.scheduledTimer(timeInterval: 0.001, target: self, selector: #selector(scrollTimerTriggered(timer:)), userInfo: nil, repeats: true)
  }
  
  
  @objc func scrollTimerTriggered(timer: Timer) {
    // let dif = fabs(scrollPoint!.y - endPoint!.y) / 1000.0
    let modifier: CGFloat = scrollingUp ? -2 : 2
    
    scrollPoint = CGPoint(x: scrollPoint!.x, y: scrollPoint!.y + modifier) //(modifier * dif))
    collectionNode.contentOffset = scrollPoint!
    
    if scrollingUp && collectionNode.contentOffset.y <= endPoint!.y {
      collectionNode.contentOffset = endPoint!
      timer.invalidate()
      scrollCompletion?()
    } else if !scrollingUp && collectionNode.contentOffset.y >= endPoint!.y {
      collectionNode.contentOffset = endPoint!
      timer.invalidate()
      scrollCompletion?()
    }
  }
  
  
  func scrollTo(storyIndex: Int, slow: Bool = false, completion: (()->())? = nil) {
    
    if slow {
      scrollToIndexPath(path: toIndexPath(from: storyIndex)) {
        self.delegate?.collectionNodeDidStopScrolling?()
      }
    } else {
      switch layoutType {
      case .carousel:
        collectionNode.scrollToItem(at: toIndexPath(from: storyIndex), at: .centeredHorizontally, animated: true)
      case .mosaic:
        collectionNode.scrollToItem(at: toIndexPath(from: storyIndex), at: .top, animated: true)
      }
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
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
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

  
  func updateStory(_ story: FoodieStory) {
    let storyIdx = storyArray.index(of: story)

    guard let storyIndex = storyIdx else {
      CCLog.warning("Story not found in the storyArray. Nothing to update")
      return
    }

    storyArray[storyIndex] = story
    collectionNode.reloadItems(at: [IndexPath(item: storyIndex, section: 0)])
  }
  
  
  func showSelectionFrameAround(story: FoodieStory) {
    if let storyIdx = storyArray.index(of: story) {
      showSelectionFrameAround(storyIndex: storyIdx)
    }
  }
  
  func showSelectionFrameAround(storyIndex: Int) {
    clearSelectionFrame()
    
    if let cellNode = collectionNode.nodeForItem(at: toIndexPath(from: storyIndex)) {
      selectedStoryIndex = storyIndex
      cellNode.layer.borderColor = Constants.SelectionFrameColor
      cellNode.layer.borderWidth = Constants.SelectionFrameWidth
      
//      let cornerRadius = Constants.DefaultGuestimatedCellNodeWidth * CGFloat(Constants.DefaultFeedNodeCornerRadiusFraction)
//      let pointA = CGPoint(x: cornerRadius, y: cellNode.bounds.height)
//      let pointB = CGPoint(x: cellNode.bounds.width - cornerRadius, y: cellNode.bounds.height)
//      let underlinePath = UIBezierPath()
//      underlinePath.move(to: pointA)
//      underlinePath.addLine(to: pointB)
//
//      let selectionLayer = CAShapeLayer()
//      selectionLayer.frame = cellNode.bounds
//      selectionLayer.path = underlinePath.cgPath
//      selectionLayer.strokeColor = FoodieGlobal.Constants.ThemeColor.cgColor
//      selectionLayer.lineWidth = 3.0 // Constants.SelectionFrameWidth
//      selectionLayer.lineCap = kCALineCapRound
//      selectedLayer = selectionLayer
//
//      cellNode.layer.addSublayer(selectionLayer)
    }
  }
  
  func clearSelectionFrame() {
    if let selectedStoryIndex = selectedStoryIndex,
      let cellNode = collectionNode.nodeForItem(at: toIndexPath(from: selectedStoryIndex)) {
      cellNode.layer.borderColor = UIColor.clear.cgColor
      cellNode.layer.borderWidth = 0.0
    }
    
//    if let selectedLayer = selectedLayer {
//      selectedLayer.removeFromSuperlayer()
//    }
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
    let story = storyArray[toStoryIndex(from: indexPath)]
    let cellNode = FeedCollectionCellNode(story: story, edit: enableEdit)
    cellNode.layer.cornerRadius = Constants.DefaultGuestimatedCellNodeWidth * CGFloat(Constants.DefaultFeedNodeCornerRadiusFraction)
    cellNode.placeholderEnabled = true
    cellNode.backgroundColor = UIColor.clear
    cellNode.isOpaque = false
    
    if enableEdit {
      guard let coverEditButton = cellNode.coverEditButton else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("Edit enabeld but coverEditButton is nil")
        }
        return { return cellNode }
      }
      coverEditButton.tag = indexPath.row
      coverEditButton.addTarget(self, action: #selector(editStory(_:)), forControlEvents: .touchUpInside)
      coverEditButton.accessibilityIdentifier = "coverEditButton_" + String(toStoryIndex(from: indexPath))
    }
    
    return { return cellNode }
  }
}



// MARK: - AsyncDisplayKit Collection Delegate Protocol Conformance

extension FeedCollectionNodeController: ASCollectionDelegateFlowLayout {
  
  func collectionNode(_ collectionNode: ASCollectionNode, didSelectItemAt indexPath: IndexPath) {
    displayStory(didSelectItemAt: indexPath)
  }
  
  
  func shouldBatchFetch(for collectionNode: ASCollectionNode) -> Bool {
    return false // !allPagesFetched
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
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
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.fatal("Did not recognize CollectionNode Layout Type")
      }
      return UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
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
      
//      Disabling Paging Here
//      if !allPagesFetched, scrollView.contentOffset.x > maxContentOffsetX + Constants.CarouselPullTrasnlationForBatchFetch {
//        carouselBatchPending = true
//      }
      
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
    displayStoryIfDeepLink()
  }
  
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      delegate?.collectionNodeDidStopScrolling?()
      displayStoryIfDeepLink()
    }
  }
  
  
  func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    delegate?.collectionNodeDidStopScrolling?()
    displayStoryIfDeepLink()
  }
}


extension FeedCollectionNodeController: MosaicCollectionViewLayoutDelegate {
  internal func collectionView(_ collectionView: UICollectionView, layout: MosaicCollectionViewLayout, originalItemSizeAtIndexPath: IndexPath) -> CGSize {
    //CCLog.verbose("collectionView(:MosaicLayout:originalItemSizeAt:\(originalItemSizeAtIndexPath.item))")
    return layout.calculateConstrainedSize(for: collectionNode.bounds).max
  }
}

