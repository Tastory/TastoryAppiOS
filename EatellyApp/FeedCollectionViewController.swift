//
//  FeedCollectionViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit


class FeedCollectionViewController: UICollectionViewController {
  
  // MARK: - Private Class Constants
  fileprivate struct Constants {
    static let reuseIdentifier = "FeedCell"
  }
  
  
  // MARK: - Private Instance Variable
  var journalQuery: FoodieQuery!
  var journalArray = [FoodieJournal]()
  
  
  // MARK: - IBActions
  @IBAction func rightSwipeAction(_ sender: UISwipeGestureRecognizer) {
    // Stop all prefetches
    FoodiePrefetch.global.removeAllPrefetchWork()
    dismiss(animated: true, completion: nil)
  }
  
  
  // MARK: - View Controller Lifecycle Functions
  override func viewDidLoad() {
    super.viewDidLoad()

    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    CCLog.verbose("journalArray.count = \(journalArray.count)")
    
    // Turn on CollectionView prefetching
    collectionView?.prefetchDataSource = self
    collectionView?.isPrefetchingEnabled = true
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    FoodiePrefetch.global.unblockPrefetching()
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("FeedCollectionViewController.didReceiveMemoryWarning")
  }
  
  
  // MARK: - Public Instance Functions
//  func queryResultCallback(objectArray: [AnyObject]?, error: Error?) {
//  
//    guard let journalArray = objectArray as? [FoodieJournal] else {
//      queryErrorDialog()
//      CCLog.assert("queryResultCallback() did not return an array of Foodie Journals")
//      return
//    }
//    numberOfItemsQueried += journalArray.count
//    CCLog.verbose("\(journalArray.count) Journals returned. Total Journals retrieved at \(numberOfItemsQueried)")
//    
//    for journal in journalArray {
//      journalArray.append(journal)
//    }
//    
//    collectionView?.reloadData()
//  }
  
  
  // MARK: - Private Instance Functions
  
  // Generic error dialog box to the user on internal errors
  fileprivate func queryErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Feed Collection View query error occurred",
                                              message: "A query error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Feed Collection View query error occurred",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic Feed Collection View errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  fileprivate func fetchErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Feed Collection View fetch error occurred",
                                              message: "A fetch error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Feed Collection View fetch error occurred",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic Feed Collection View errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  fileprivate func internalErrorDialog() {
    if self.presentedViewController == nil {
      let alertController = UIAlertController(title: "SomeFoodieApp",
                                              titleComment: "Alert diaglogue title when a Feed Collection View internal error occured",
                                              message: "An internal error has occured. Please try again",
                                              messageComment: "Alert dialog message when a Feed Collection View internal error occured",
                                              preferredStyle: .alert)
      alertController.addAlertAction(title: "OK",
                                     comment: "Button in alert dialog box for generic Feed Collection View errors",
                                     style: .default)
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  
  func viewJournal(_ sender: UIButton) {
    // Stop all prefetches
    FoodiePrefetch.global.blockPrefetching()
    
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "JournalViewController") as! JournalViewController
    viewController.viewingJournal = journalArray[sender.tag]
    self.present(viewController, animated: true)
  }
  
  
  // MARK: - UICollectionViewDataSource
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return journalArray.count
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let reusableCell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.reuseIdentifier, for: indexPath) as! FeedCollectionViewCell
    
    // Configure the cell
    let journal = journalArray[indexPath.row]
    reusableCell.journalButton.tag = indexPath.row
    reusableCell.journalButton.addTarget(self, action: #selector(viewJournal(_:)), for: .touchUpInside)
    reusableCell.activityIndicator.isHidden = false
    reusableCell.activityIndicator.startAnimating()
    
    // CCLog.verbose("collectionView(cellForItemAt #\(indexPath.row)")
    
    FoodiePrefetch.global.blockPrefetching()
    
    journal.selfRetrieval { journalError in
      
      FoodiePrefetch.global.unblockPrefetching()
      
      if let error = journalError {
        self.fetchErrorDialog()
        CCLog.assert("Journal.selfRetrieval() callback with error: \(error.localizedDescription)")
        return
      }
      
      guard let thumbnailObject = journal.thumbnailObj else {
        self.fetchErrorDialog()
        CCLog.assert("Journal.selfRetrieval callback with thumbnailObj = nil")
        return
      }
      
      guard let thumbnailData = thumbnailObject.imageMemoryBuffer else {
        self.internalErrorDialog()
        CCLog.assert("Unexpected, thumbnailObject.imageMemoryBuffer = nil")
        return
      }
      
      DispatchQueue.main.async {
        var letsPrefetch = false
        
        if let cell = collectionView.cellForItem(at: indexPath) as? FeedCollectionViewCell {
          // CCLog.verbose("cellForItem(at:) DispatchQueue.main for cell #\(indexPath.row)")
          cell.journalTitle?.text = self.journalArray[indexPath.row].title
          cell.journalButton?.setImage(UIImage(data: thumbnailData), for: .normal)
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
          reusableCell.journalTitle?.text = self.journalArray[indexPath.row].title
          reusableCell.journalButton?.setImage(UIImage(data: thumbnailData), for: .normal)
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
          let journal = self.journalArray[indexPath.row]
          journal.contentPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: journal, on: journal)
        }
      }
    }
    return reusableCell
  }

  
  // MARK: - UICollectionViewDataSource
  
  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    
    guard let feedCell = cell as? FeedCollectionViewCell else {
      internalErrorDialog()
      CCLog.assert("Cannot cast cell as FeedCollectionViewCell")
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
      let journal = self.journalArray[indexPath.row]
      journal.contentPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: journal, on: journal)
    }
  }
  
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    CCLog.verbose("collectionView didEndDisplayingCell indexPath.row = \(indexPath.row)")
    let journal = journalArray[indexPath.row]
    if let context = journal.contentPrefetchContext {
      FoodiePrefetch.global.removePrefetchWork(for: context)
    }
  }
}
  
  
extension FeedCollectionViewController: UICollectionViewDataSourcePrefetching {
  
  func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      CCLog.verbose("collectionView prefetchItemsAt indexPath.row = \(indexPath.row)")
      let journal = journalArray[indexPath.row]
      journal.selfPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: journal, on: journal)
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      CCLog.verbose("collectionView cancelPrefetchingForItemsAt indexPath.row = \(indexPath.row)")
      let journal = journalArray[indexPath.row]
      if let context = journal.selfPrefetchContext {
        FoodiePrefetch.global.removePrefetchWork(for: context)
      }
    }
  }
}
