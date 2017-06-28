//
//  FeedCollectionViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit


class FeedCollectionViewController: UICollectionViewController {
  
  // MARK: - Private Class Constants
  fileprivate struct Constants {
    static let reuseIdentifier = "FeedCell"
  }
  
  
  // MARK: - Private Instance Variable
  var numberOfItemsQueried: Int = 0
  var queriedJournalArray = [FoodieJournal]()
  
  
  // MARK: - IBActions
  @IBAction func rightSwipeAction(_ sender: UISwipeGestureRecognizer) {
    // Stop all prefetches
    FoodiePrefetch.global.removeAllPrefetchWork()
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func DeleteTestBtn(_ sender: Any) {
    
    // test delete one moment
    /*
    if let hasMoments = queriedJournalArray[0].moments {
      // delete delete moment from journal
      hasMoments[1].deleteRecursive(from: .server, withName: nil, withBlock: { (success,error)->Void in
        if(success)
        {
          DebugPrint.userAction("Successfully Deleted Journal")
        }
      })
    }*/
    
    
    queriedJournalArray[0].deleteAsync() { success, error in
      if success {
        DebugPrint.userAction("Successfully Deleted Journal")
      } else {
        DebugPrint.userAction("Delete Journal Failed")
      }
    }
  }
  
  // MARK: - View Controller Lifecycle Functions
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Do any additional setup after loading the view
    FoodieJournal.queryAll(limit: 20, block: queryResultCallback)  // TODO: Don't hardcode this limit
    
    // Turn on CollectionView prefetching
    collectionView?.prefetchDataSource = self
    collectionView?.isPrefetchingEnabled = true
  }
  
  
  override func viewDidAppear(_ animated: Bool) {
    FoodiePrefetch.global.unblockPrefetching()
  }
  
  
  // MARK: - Public Instance Functions
  func queryResultCallback(objectArray: [AnyObject]?, error: Error?) {
  
    guard let journalArray = objectArray as? [FoodieJournal] else {
      queryErrorDialog()
      DebugPrint.assert("queryResultCallback() did not return an array of Foodie Journals")
      return
    }
    numberOfItemsQueried += journalArray.count
    DebugPrint.verbose("\(journalArray.count) Journals returned. Total Journals retrieved at \(numberOfItemsQueried)")
    
    for journal in journalArray {
      queriedJournalArray.append(journal)
    }
    
    collectionView?.reloadData()
  }
  
  
  // MARK: - Private Instance Functions
  
  // Generic error dialog box to the user on internal errors
  func queryErrorDialog() {
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
  
  
  func fetchErrorDialog() {
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
  
  func internalErrorDialog() {
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
    viewController.restorationClass = nil
    viewController.viewingJournal = queriedJournalArray[sender.tag]
    self.present(viewController, animated: true)
  }
  
  
  // MARK: - UICollectionViewDataSource
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return numberOfItemsQueried
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let reusableCell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.reuseIdentifier, for: indexPath) as! FeedCollectionViewCell
    
    // Configure the cell
    let journal = queriedJournalArray[indexPath.row]
    reusableCell.journalButton.tag = indexPath.row
    reusableCell.journalButton.addTarget(self, action: #selector(viewJournal(_:)), for: .touchUpInside)
    
    // DebugPrint.verbose("collectionView(cellForItemAt #\(indexPath.row)")
    
    FoodiePrefetch.global.blockPrefetching()
    
    journal.selfRetrieval { journalError in
      
      FoodiePrefetch.global.unblockPrefetching()
      
      if let error = journalError {
        self.fetchErrorDialog()
        DebugPrint.assert("Journal.selfRetrieval() callback with error: \(error.localizedDescription)")
        return
      }
      
      guard let thumbnailObject = journal.thumbnailObj else {
        self.fetchErrorDialog()
        DebugPrint.assert("Journal.selfRetrieval callback with thumbnailObj = nil")
        return
      }
      
      guard let thumbnailData = thumbnailObject.imageMemoryBuffer else {
        self.internalErrorDialog()
        DebugPrint.assert("Unexpected, thumbnailObject.imageMemoryBuffer = nil")
        return
      }
      
      DispatchQueue.main.async {
        var letsPrefetch = false
        
        if let cell = collectionView.cellForItem(at: indexPath) as? FeedCollectionViewCell {
          // DebugPrint.verbose("cellForItem(at:) DispatchQueue.main for cell #\(indexPath.row)")
          cell.journalTitle?.text = self.queriedJournalArray[indexPath.row].title
          cell.journalButton?.setImage(UIImage(data: thumbnailData), for: .normal)
          
          pthread_mutex_lock(&cell.cellStatusMutex)
          cell.cellLoaded = true
          if cell.cellDisplayed {
            letsPrefetch = true
          }
          pthread_mutex_unlock(&cell.cellStatusMutex)
          
        } else {
          // None of the retrieve function actually did an async dispatch. So we are still in the collectionView.cellForItemAt context.
          reusableCell.journalTitle?.text = self.queriedJournalArray[indexPath.row].title
          reusableCell.journalButton?.setImage(UIImage(data: thumbnailData), for: .normal)
          
          pthread_mutex_lock(&reusableCell.cellStatusMutex)
          reusableCell.cellLoaded = true
          if reusableCell.cellDisplayed {
            letsPrefetch = true
          }
          pthread_mutex_unlock(&reusableCell.cellStatusMutex)
        }
        
        if letsPrefetch {
          let journal = self.queriedJournalArray[indexPath.row]
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
      DebugPrint.assert("Cannot cast cell as FeedCollectionViewCell")
      return
    }
    
    var letsPrefetch = false
    pthread_mutex_lock(&feedCell.cellStatusMutex)
    feedCell.cellDisplayed = true
    if feedCell.cellLoaded {
      letsPrefetch = true
    }
    pthread_mutex_unlock(&feedCell.cellStatusMutex)
    
    if letsPrefetch {
      let journal = self.queriedJournalArray[indexPath.row]
      journal.contentPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: journal, on: journal)
    }
  }
  
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    DebugPrint.verbose("collectionView didEndDisplayingCell indexPath.row = \(indexPath.row)")
    let journal = queriedJournalArray[indexPath.row]
    if let context = journal.contentPrefetchContext {
      FoodiePrefetch.global.removePrefetchWork(for: context)
    }
  }
}
  
  
extension FeedCollectionViewController: UICollectionViewDataSourcePrefetching {
  
  func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      DebugPrint.verbose("collectionView prefetchItemsAt indexPath.row = \(indexPath.row)")
      let journal = queriedJournalArray[indexPath.row]
      journal.selfPrefetchContext = FoodiePrefetch.global.addPrefetchWork(for: journal, on: journal)
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
      DebugPrint.verbose("collectionView cancelPrefetchingForItemsAt indexPath.row = \(indexPath.row)")
      let journal = queriedJournalArray[indexPath.row]
      if let context = journal.selfPrefetchContext {
        FoodiePrefetch.global.removePrefetchWork(for: context)
      }
    }
  }
}
