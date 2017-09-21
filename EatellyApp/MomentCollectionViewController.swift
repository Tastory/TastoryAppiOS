//
//  MomentCollectionViewController.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-04-28.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class MomentCollectionViewController: UICollectionViewController {

  // MARK: - Public Instance Variables
  var momentHeight: CGFloat?


  // MARK: - Private Class Constants
  fileprivate struct Constants {
    static let momentCellReuseId = "MomentCell"
    static let headerElementReuseId = "MomentHeader"
    static let footerElementReuseId = "MomentFooter"
    static let interitemSpacing: CGFloat = 5
  }


  // MARK: - Public Instance Variables
  var workingJournal: FoodieJournal!


  // MARK: - Private Instance Variables
  fileprivate var momentWidthDefault: CGFloat!
  fileprivate var momentSizeDefault: CGSize!

  // MARK: - IBActions
  @IBAction func longPressAction(_ lpgr: UILongPressGestureRecognizer) {
    let point = lpgr.location(in: self.collectionView)

    if let indexPath = collectionView!.indexPathForItem(at: point) {
      setThumbnail(at: indexPath)
    } else {
      // Ignore, not long pressing on a valid Moment Thumbnail
    }
  }

  // MARK: - Private Instance Functions
  fileprivate func setThumbnail(at indexPath: IndexPath)
  {
    let cell = collectionView!.cellForItem(at: indexPath) as! MomentCollectionViewCell

    guard let momentArray = workingJournal.moments else {
      CCLog.fatal("No Moments but Moment Thumbnail long pressed? What?")
    }

    // Clear the last thumbnail selection if any
    if workingJournal.thumbnailFileName != nil {
      var momentArrayIndex = 0
      for moment in momentArray {
        if workingJournal.thumbnailFileName == moment.thumbnailFileName {
          let oldIndexPath = IndexPath(row: momentArrayIndex, section: indexPath.section)

          // If the oldIndexPath is same as the pressed indexPath, nothing to do here really.
          if oldIndexPath != indexPath {
            if let oldCell = collectionView!.cellForItem(at: oldIndexPath) as? MomentCollectionViewCell {
              oldCell.thumbFrameView.isHidden = true
            } else {
              collectionView!.reloadItems(at: [oldIndexPath])
            }
          }
          break
        }
        momentArrayIndex += 1
      }
    }

    // Long Press detected on a Moment Thumbnail. Set that as the Journal Thumbnail
    // TODO: Do we need to factor out thumbnail operations?
    workingJournal.thumbnailFileName = momentArray[indexPath.row].thumbnailFileName
    workingJournal.thumbnailObj = momentArray[indexPath.row].thumbnailObj

    // Unhide the Thumbnail Frame to give feedback to user that this is the Journal Thumbnail
    cell.thumbFrameView.isHidden = false
  }

  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    guard let momentHeightUnwrapped = momentHeight else {
      CCLog.fatal("nil momentHeight in Moment Collection View Controller")
    }
//    // Uncomment the following line to preserve selection between presentations
//    self.clearsSelectionOnViewWillAppear = false
//    self.automaticallyAdjustsScrollViewInsets = false  // Added in attempt to fix Undefined Layout issue. Not needed anymore

    // Setup Dimension Variables
    momentWidthDefault = momentHeightUnwrapped/(16/9)
    momentSizeDefault = CGSize(width: momentWidthDefault, height: momentHeightUnwrapped)

    // Setup the Moment Colleciton Layout
    // Note: Setting either layout.itemSize or layout.estimatedItemSize will cause crashes
    let layout = collectionViewLayout as! UICollectionViewFlowLayout
    layout.minimumLineSpacing = Constants.interitemSpacing
    layout.minimumInteritemSpacing = Constants.interitemSpacing
    layout.headerReferenceSize = momentSizeDefault
    layout.footerReferenceSize = momentSizeDefault
    layout.sectionInset = UIEdgeInsets(top: 0, left: Constants.interitemSpacing,
                                       bottom: 0, right: Constants.interitemSpacing)
    self.collectionView?.contentInset = UIEdgeInsetsMake(0.0, CGFloat(-1.0*momentWidthDefault), 0.0, 0.0)
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    
    CCLog.warning("MomentCollectionViewController.didReceiveMemoryWarning")
  }
}


// MARK: - Collection View DataSource
extension MomentCollectionViewController {

  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }


  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

    if let moments = workingJournal.moments {
      return moments.count
    } else {
      return 10
    }
  }


  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.momentCellReuseId, for: indexPath) as! MomentCollectionViewCell
    guard let momentArray = workingJournal.moments else {
      CCLog.warning("No Moments for workingStory \(workingJournal.getUniqueIdentifier())")
      return cell
    }
    
    if indexPath.row >= momentArray.count {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
        CCLog.assert("Moment Array for Story \(self.workingJournal.getUniqueIdentifier()) index out of range - indexPath.row \(indexPath.row) >= momentArray.count \(momentArray.count)")
      }
      return cell
    }
    
    let moment = momentArray[indexPath.row]
    
    guard let thumbnailObj = moment.thumbnailObj else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
        CCLog.assert("No Thumbnail Object for Moment \(moment.getUniqueIdentifier())")
      }
      return cell
    }
    
    guard let thumbnailFileName = moment.thumbnailFileName else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
        CCLog.assert("No Thumbnail Filename for Moment \(moment.getUniqueIdentifier())")
      }
      return cell
    }
    
    // TODO: Download the moment if not in memory
//    moment.fetchIfNeededInBackground { (object, error) in
//      
//      if let err = error {
//        CCLog.fatal("Error fetching moment: \(err)")
//      }
//      
//      guard let moment = object as? FoodieMoment else {
//        CCLog.fatal("fetched Object is not a FoodieMoment")
//      }
//      
//      guard let file = moment.media else {
//        CCLog.fatal("Moment Media is nil")
//      }
//      
//      file.getDataInBackground { (data, error) in
//        
//        if let err = error {
//          CCLog.fatal("Error getting media data: \(err)")
//        }
//        
//        guard let imageData = data else {
//          CCLog.fatal("nil data obtained from media file")
//        }
//        
//        if let image = UIImage(data: imageData) {
//          
//          if let currentCell = collectionView.cellForItem(at: indexPath) as? MomentCollectionViewCell {
//            currentCell.momentButton.setImage(image, for: .normal)
//          } else {
//            CCLog.debug("MomentCollectionViewCell not visible or indexPath is out of range")
//          }
//          
//        } else {
//          CCLog.fatal("Error getting image from image data")
//        }
//      }
//    }
    
    // TODO: Download the thumbnail here if not a local draft?
    if thumbnailObj.imageMemoryBuffer == nil {
      do {
        try thumbnailObj.imageMemoryBuffer = Data(contentsOf: FoodieFile.Constants.DraftStoryMediaFolderUrl.appendingPathComponent(thumbnailFileName))
      } catch {
        AlertDialog.present(from: self, title: "File Read Error", message: "Cannot read image file from local flash storage") { action in
          CCLog.assert("Cannot read image file \(thumbnailFileName)")
        }
        return cell
      }
    }

    thumbnail = UIImage(data: moment.thumbnailObj!.imageMemoryBuffer!)
    cell.momentThumb.image = thumbnail
  
    // Should Thumbnail frame be hidden?
    cell.createFrameLayer()
    if workingJournal.thumbnailFileName != nil, workingJournal.thumbnailFileName == moment.thumbnailFileName {
      cell.thumbFrameView.isHidden = false
    } else {
      cell.thumbFrameView.isHidden = true
    }

    cell.delegate = self

    return cell
  }


  override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

    var reusableView: UICollectionReusableView!

    switch kind {
    case UICollectionElementKindSectionHeader:
      reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: Constants.headerElementReuseId, for: indexPath)
    case UICollectionElementKindSectionFooter:
      reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: Constants.footerElementReuseId, for: indexPath)
    default:
      CCLog.fatal("Unrecognized Kind '\(kind)' for Supplementary Element")
    }
    return reusableView
  }
}


// MARK: - Collection View Flow Layout Delegate
extension MomentCollectionViewController: UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    guard let momentArray = workingJournal.moments else {
      CCLog.debug("No Moments for workingJournal")
      return momentSizeDefault
    }
    if indexPath.row >= momentArray.count {
      CCLog.assert("indexPath.row >= momentArray.count")
      return momentSizeDefault
    }
    let moment = momentArray[indexPath.row]
    return CGSize(width: momentHeight!/CGFloat(moment.aspectRatio), height: momentHeight!)
  }
}

extension MomentCollectionViewController: MomentCollectionViewCellDelegate {

  func deleteMoment(sourceCell cell: MomentCollectionViewCell) {

    // make sure you get confirmation from user before deleting 
  AlertDialog.presentConfirm(from: self, title: "Deleting a moment", message: "Do you want to delete this moment?"){ action in

      guard let collectionView = self.collectionView else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
          CCLog.assert("collection view is nil")
        }
        return
      }

      if let indexPath = collectionView.indexPath(for: cell) {
        guard let momentArray = self.workingJournal.moments else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("No Moments for workingJournal")
          }
          return
        }

        if indexPath.item >= momentArray.count {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Deleting a moment from an out of bound index")
          }
          return
        }

        if(momentArray.count == 1)
        {
          AlertDialog.present(from: self, title: "Delete Error", message: "Each story must contain at least one moment") { action in
            CCLog.info("User tried to remove the last Moment from Story")
          }
          return
        }

        let moment = momentArray[indexPath.item]

        // if the deleted item is the one with the thumnail, select next in the list
        if self.workingJournal.thumbnailFileName == moment.thumbnailFileName {

          var rowIdx = indexPath.row + 1
          if(rowIdx >= momentArray.count)
          {
            rowIdx = indexPath.row - 1
          }

          // row is the index of the moment array
          self.setThumbnail(at: IndexPath(row: rowIdx, section: indexPath.section))
        }

        self.workingJournal.moments?.remove(at: indexPath.item)
        moment.deleteRecursive(withName: FoodieGlobal.Constants.SavedDraftPinName) { (success, error) in
          if let error = error {
            CCLog.warning("Failed to delete moments from pending delete moment lists: \(error)")
          }
        }

        //TODO pre-save this journal 
        // cant access JournalEntryVC from this controller not sure how to presave like we do in
        // journal entry view controller.

        // there seems to be a few seconds delay when not refreshing from the main thread
        DispatchQueue.main.async {
          collectionView.reloadData()
        }
      }
    }
  }
}

//TODO need to figure a better way to return from moment markup back to journalentry VC 
extension MomentCollectionViewController: MarkupReturnDelegate {
  func markupComplete(markedupMoment: FoodieMoment, suggestedJournal: FoodieJournal?) {
    self.dismiss(animated: true, completion: nil)
  }
}