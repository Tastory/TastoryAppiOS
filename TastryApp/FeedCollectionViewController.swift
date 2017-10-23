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
  var scrollViewInset: CGFloat = 0.0
  var columns: CGFloat = Constants.DefaultColumns
  var padding: CGFloat = Constants.DefaultPadding
  var cellAspectRatio: CGFloat = FoodieGlobal.Constants.DefaultMomentAspectRatio

  var storyQuery: FoodieQuery!
  var storyArray = [FoodieStory]()
  
  
  // MARK: - Private Instance Function
  private func loadImage(to cell: UICollectionViewCell? = nil, in collectionView: UICollectionView, forItemAt indexPath: IndexPath) {
    
    if let reusableCell = (cell ?? collectionView.cellForItem(at: indexPath)) as? FeedCollectionViewCell {
      guard let thumbnailObject = storyArray[indexPath.row].thumbnail else {
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
      
      reusableCell.storyTitle?.text = storyArray[indexPath.row].title
      reusableCell.storyButton?.setImage(UIImage(data: thumbnailData), for: .normal)
      reusableCell.storyButton?.imageView?.contentMode = .scaleAspectFill
      reusableCell.activityIndicator?.isHidden = true
      reusableCell.activityIndicator?.stopAnimating()
      reusableCell.cellStory = storyArray[indexPath.row]
    } else {
      CCLog.debug("No cell provided or found to display Story \(storyArray[indexPath.row].getUniqueIdentifier())!!!")
      collectionView.reloadItems(at: [indexPath])
    }
  }
  
  
  
  // MARK: - Public Instance Functions
  func reloadData() {
    collectionView?.reloadData()
  }
  
  
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
  
  
  
  // MARK: - View Controller Lifecycle Functions
  override func viewDidLoad() {
    super.viewDidLoad()
    CCLog.verbose("StoryArray.count = \(storyArray.count)")

    // Turn on CollectionView prefetching
    //collectionView?.prefetchDataSource = self
    collectionView?.isPrefetchingEnabled = true
  }
  
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Don't Cancel!!! viewDidDisappear actually gets triggered even when presenting the StoryVC.   FoodieFetch.global.cancelAll()
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
    reusableCell.storyButton?.tag = indexPath.row
    reusableCell.storyButton?.addTarget(self, action: #selector(viewStory(_:)), for: .touchUpInside)
    
    var shouldRetrieveDigest = false
    
    story.executeForDigest(ifNotReady: {
      CCLog.debug("Digest \(story.getUniqueIdentifier()) not yet loaded")
      shouldRetrieveDigest = true  // Don't execute the retrieve here. This is actually executed inside of a mutex
      
    }, whenReady: {
      CCLog.debug("Digest \(story.getUniqueIdentifier()) ready to display")
      DispatchQueue.main.async { self.loadImage(in: collectionView, forItemAt: indexPath) }
    })
    
    if shouldRetrieveDigest {
      reusableCell.activityIndicator?.isHidden = false
      reusableCell.activityIndicator?.startAnimating()
      let digestOperation = StoryOperation(with: .digest, on: story, completion: nil)
      FoodieFetch.global.queue(digestOperation, at: .high)
      
    } else {
      CCLog.debug("Direct load image for Story \(story.getUniqueIdentifier())")
      loadImage(to: reusableCell, in: collectionView, forItemAt: indexPath)
    }
    return reusableCell
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    if let feedCell = cell as? FeedCollectionViewCell {
      feedCell.cellDisplayed = true
    }
  }


  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    if let feedCell = cell as? FeedCollectionViewCell {
      feedCell.cellDisplayed = false
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
      let digestOperation = StoryOperation(with: .digest, on: storyArray[indexPath.row], completion: nil)
      FoodieFetch.global.queue(digestOperation, at: .low)
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      CCLog.verbose("collectionView cancelPrefetchingForItemsAt indexPath.row = \(indexPath.row)")
      FoodieFetch.global.cancel(for: storyArray[indexPath.row])
    }
  }
}
