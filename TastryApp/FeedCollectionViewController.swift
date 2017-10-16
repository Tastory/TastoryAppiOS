//
//  FeedCollectionViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit


class FeedCollectionViewController: UICollectionViewController {
  
  // MARK: - Private Class Constants
  private struct Constants {
    static let ReuseIdentifier = "FeedCell"
    static let DefaultColumns: CGFloat = 2.0
    static let DefaultPadding: CGFloat = 1.0
  }
  
  
  
  // MARK: - Public Instance Variable
  var storyQuery: FoodieQuery!
  var scrollViewInset: CGFloat = 0.0
  var columns: CGFloat = Constants.DefaultColumns
  var padding: CGFloat = Constants.DefaultPadding
  var cellAspectRatio: CGFloat = FoodieGlobal.Constants.DefaultMomentAspectRatio

  var storyArray = [FoodieStory]()
  
  
  
  // MARK: - Public Instance Functions
  func reloadData() {
    collectionView?.reloadData()
  }
  
  
  @objc func viewStory(_ sender: UIButton) {
    // Stop all prefetches
    // TODO: - Reinstate Prefetch  FoodiePrefetch.global.blockPrefetching()
    
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
  
  
  
  // MARK: - View Controller Lifecycle Functions
  override func viewDidLoad() {
    super.viewDidLoad()
    CCLog.verbose("StoryArray.count = \(storyArray.count)")

    // Turn on CollectionView prefetching
    // TODO: - Reinstate Prefetch  collectionView?.prefetchDataSource = self
    // TODO: - Reinstate Prefetch  collectionView?.isPrefetchingEnabled = true
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    FoodiePrefetch.global.unblockPrefetching()
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    FoodiePrefetch.global.removeAllPrefetchWork()
  }
  
  
  override func viewDidLayoutSubviews() {
    collectionView?.contentInset = UIEdgeInsetsMake(scrollViewInset, 0.0, 0.0, 0.0)  // This is so the Table View can be translucent underneath the Stack View of Search Bars
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("didReceiveMemoryWarning")
  }
  
  
  
  // MARK: - UICollectionViewDataSource
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return storyArray.count
  }
  
  
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let reusableCell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.ReuseIdentifier, for: indexPath) as! FeedCollectionViewCell
    
    // Configure the cell
    let story = storyArray[indexPath.row]
    reusableCell.storyButton.tag = indexPath.row
    reusableCell.storyButton.addTarget(self, action: #selector(viewStory(_:)), for: .touchUpInside)
    reusableCell.activityIndicator.isHidden = false
    reusableCell.activityIndicator.startAnimating()
    
    // CCLog.verbose("collectionView(cellForItemAt #\(indexPath.row)")
    
    FoodiePrefetch.global.blockPrefetching()
    
    story.retrieveDigest(from: .both, type: .cache) { error in
      
      FoodiePrefetch.global.unblockPrefetching()
      
      if let error = error {
        AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Story - \(error.localizedDescription)") { action in
          CCLog.assert("Story.retrieveDigest() callback with error: \(error.localizedDescription)")
        }
        return
      }
      
      guard let thumbnailObject = story.thumbnail else {
        AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Cover Media") { action in
          CCLog.assert("Story.retrieveDigest callback with thumbnailObj = nil")
        }
        return
      }
      
      guard let thumbnailData = thumbnailObject.imageMemoryBuffer else {
        AlertDialog.present(from: self, title: "Story Retrieve Error", message: "Failed to retrieve Cover Media") { action in
          CCLog.assert("Unexpected, thumbnailObject.imageMemoryBuffer = nil")
        }
        return
      }
      
      DispatchQueue.main.async {
        var letsPrefetch = false
        
        if let cell = collectionView.cellForItem(at: indexPath) as? FeedCollectionViewCell {
          // CCLog.verbose("cellForItem(at:) DispatchQueue.main for cell #\(indexPath.row)")
          cell.storyTitle?.text = self.storyArray[indexPath.row].title
          cell.storyButton?.setImage(UIImage(data: thumbnailData), for: .normal)
          cell.activityIndicator.isHidden = true
          cell.activityIndicator.stopAnimating()
          
          SwiftMutex.lock(&cell.cellStatusMutex)  // TODO-Performance: Is there another way to do this? Lock in Main Thread here
          cell.cellLoaded = true
          if cell.cellDisplayed {
            letsPrefetch = true
          }
          SwiftMutex.unlock(&cell.cellStatusMutex)
          
        } else {
          // This is an out of view prefetch?
          reusableCell.storyTitle?.text = self.storyArray[indexPath.row].title
          reusableCell.storyButton?.setImage(UIImage(data: thumbnailData), for: .normal)
          reusableCell.storyButton?.imageView?.contentMode = .scaleAspectFill
          reusableCell.activityIndicator.isHidden = true
          reusableCell.activityIndicator.stopAnimating()
          
          SwiftMutex.lock(&reusableCell.cellStatusMutex)  // TODO-Performance: Is there another way to do this? Lock in Main Thread here
          reusableCell.cellLoaded = true
          if reusableCell.cellDisplayed {
            letsPrefetch = true
          }
          SwiftMutex.unlock(&reusableCell.cellStatusMutex)
        }
        
        if letsPrefetch {
          let story = self.storyArray[indexPath.row]
          // TODO: - Reinstate Prefetch  story.contentPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: story, on: story)
        }
      }
    }
    return reusableCell
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    guard let feedCell = cell as? FeedCollectionViewCell else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Cannot cast cell as FeedCollectionViewCell")
      }
      return
    }
    
    var letsPrefetch = false
    SwiftMutex.lock(&feedCell.cellStatusMutex)  // TODO-Performance: Is there another way to do this? Lock in Main Thread here
    feedCell.cellDisplayed = true
    if feedCell.cellLoaded {
      letsPrefetch = true
    }
    SwiftMutex.unlock(&feedCell.cellStatusMutex)
    
    if letsPrefetch {
      let story = self.storyArray[indexPath.row]
      // TODO: - Reinstate Prefetch  story.contentPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: story, on: story)
    }
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    CCLog.verbose("collectionView didEndDisplayingCell indexPath.row = \(indexPath.row)")
    let story = storyArray[indexPath.row]
    if let context = story.contentPrefetchContext {
      // TODO: - Reinstate Prefetch  FoodiePrefetch.global.removePrefetchWork(for: context)
    }
  }
}


extension FeedCollectionViewController: UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width = (collectionView.frame.width - (columns + 1) * padding) / columns
    let height = width * cellAspectRatio
    return CGSize(width: width, height: height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsetsMake(padding, padding, padding, padding)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return padding
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return padding
  }
}

  
extension FeedCollectionViewController: UICollectionViewDataSourcePrefetching {
  
  func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      CCLog.verbose("collectionView prefetchItemsAt indexPath.row = \(indexPath.row)")
      let story = storyArray[indexPath.row]
      story.selfPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: story, on: story)
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      CCLog.verbose("collectionView cancelPrefetchingForItemsAt indexPath.row = \(indexPath.row)")
      let story = storyArray[indexPath.row]
      if let context = story.selfPrefetchContext {
        FoodiePrefetch.global.removePrefetchWork(for: context)
      }
    }
  }
}
