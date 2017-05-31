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
    dismiss(animated: true, completion: nil)
  }
  
  
  // MARK: - View Controller Lifecycle Functions
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Do any additional setup after loading the view
    FoodieJournal.queryAll(limit: 10, block: queryResultCallback)
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
  
  
  func fetchErrorDialog() {
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
  
  func internalErrorDialog() {
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
  
  
  // MARK: - UICollectionViewDataSource
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return numberOfItemsQueried
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.reuseIdentifier, for: indexPath) as! FeedCollectionViewCell
    
    // Configure the cell
    let journal = queriedJournalArray[indexPath.row]
    
    // TODO: Hide all these in the Journal Model?
    
    // Do we need to fetch the Journal?
    journal.retrieve { [unowned self] _, journalError in
      
      if let error = journalError {
        self.fetchErrorDialog()
        DebugPrint.error("Journal.retrieve() callback with error: \(error.localizedDescription)")
        return
      }
      
      journal.verbose()
      
      guard let thumbnailObject = journal.thumbnailObj else {
        self.internalErrorDialog()
        DebugPrint.error("Unexpected, thumbnailObject = nil")
        return
      }
      
      thumbnailObject.retrieve(){ [unowned self] _, thumbnailError in
      
        if let error = thumbnailError {
          self.fetchErrorDialog()
          DebugPrint.error("Thumbnail.retrieve() callback with error: \(error.localizedDescription)")
          return
        }
        
        guard let thumbnailData = thumbnailObject.imageMemoryBuffer else {
          self.internalErrorDialog()
          DebugPrint.error("Unexpected, thumbnailObject.imageMemoryBuffer = nil")
          return
        }
        
        if let cell = collectionView.cellForItem(at: indexPath) as? FeedCollectionViewCell {
          DispatchQueue.main.async {
            cell.journalTitle?.text = self.queriedJournalArray[indexPath.row].title
            cell.journalButton?.setImage(UIImage(data: thumbnailData), for: .normal)
            //collectionView.reloadItems(at: [indexPath])
          }
        } else {
          DebugPrint.error("Feed Collection View CellForItemAt \(indexPath) did not return FeedCollectionViewCell type")
        }
      }
    }
    return cell
  }
  
  
  // MARK: - UICollectionViewDelegate
  
  /*
   // Uncomment this method to specify if the specified item should be highlighted during tracking
   override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
   return true
   }
   */
  
  /*
   // Uncomment this method to specify if the specified item should be selected
   override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
   return true
   }
   */
  
  /*
   // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
   override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
   return false
   }
   
   override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
   return false
   }
   
   override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
   
   }
   */
  
}
