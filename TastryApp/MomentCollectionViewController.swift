//
//  MomentCollectionViewController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-28.
//  Copyright © 2017 Tastry. All rights reserved.
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
  var workingStory: FoodieStory!
  var cameraReturnDelegate: CameraReturnDelegate!

  // MARK: - Private Instance Variables
  fileprivate var momentWidthDefault: CGFloat!
  fileprivate var momentSizeDefault: CGSize!

  // MARK: - Public Instance Functions
  @objc func openCamera(_ sender: UIGestureRecognizer) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CameraViewController") as! CameraViewController
    viewController.addToExistingStoryOnly = true
    viewController.cameraReturnDelegate = cameraReturnDelegate
    self.present(viewController, animated: true)
  }


  func setThumbnail(_ indexPath: IndexPath) {

    guard let currentStory = workingStory else {
      CCLog.assert("working story is nil")
      return
    }

    guard let momentArray = currentStory.moments else {
      CCLog.fatal("No Moments but Moment Thumbnail long pressed? What?")
    }

    guard let myCollectionView = collectionView else {
      CCLog.assert("Error unwrapping collectionView from moment view controller is nil")
      return
    }

    let cell = myCollectionView.cellForItem(at: indexPath) as! MomentCollectionViewCell

    // Clear the last thumbnail selection if any
    if currentStory.thumbnailFileName != nil {
      var momentArrayIndex = 0
      for moment in momentArray {
        if currentStory.thumbnailFileName == moment.thumbnailFileName {
          let oldIndexPath = IndexPath(row: momentArrayIndex, section: indexPath.section)

          // If the oldIndexPath is same as the pressed indexPath, nothing to do here really.
          if oldIndexPath != indexPath {
            if let oldCell = myCollectionView.cellForItem(at: oldIndexPath) as? MomentCollectionViewCell {
              oldCell.thumbFrameView.isHidden = true
            } else {
              myCollectionView.reloadItems(at: [oldIndexPath])
            }
          }
          break
        }
        momentArrayIndex += 1
      }
    }


    // Long Press detected on a Moment Thumbnail. Set that as the Story Thumbnail
    // TODO: Do we need to factor out thumbnail operations?
    currentStory.thumbnailFileName = momentArray[indexPath.row].thumbnailFileName
    currentStory.thumbnailObj = momentArray[indexPath.row].thumbnailObj

    // Unhide the Thumbnail Frame to give feedback to user that this is the Story Thumbnail
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
    
    CCLog.warning("didReceiveMemoryWarning")
  }
}


// MARK: - Collection View DataSource
extension MomentCollectionViewController {

  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }


  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

    if let moments = workingStory.moments {
      return moments.count
    } else {
      return 10
    }
  }


  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.momentCellReuseId, for: indexPath) as! MomentCollectionViewCell
    guard let momentArray = workingStory.moments else {
      CCLog.warning("No Moments for workingStory \(workingStory.getUniqueIdentifier())")
      return cell
    }
    
    if indexPath.row >= momentArray.count {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
        CCLog.assert("Moment Array for Story \(self.workingStory.getUniqueIdentifier()) index out of range - indexPath.row \(indexPath.row) >= momentArray.count \(momentArray.count)")
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

    cell.momentThumb.image = UIImage(data: moment.thumbnailObj!.imageMemoryBuffer!)
  
    // Should Thumbnail frame be hidden?
    cell.createFrameLayer()
    if workingStory.thumbnailFileName != nil, workingStory.thumbnailFileName == moment.thumbnailFileName {
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
      let triggerCamera = UITapGestureRecognizer(target: self, action: #selector(openCamera(_:)))
      triggerCamera.numberOfTapsRequired = 1
      reusableView.addGestureRecognizer(triggerCamera)

    default:
      CCLog.fatal("Unrecognized Kind '\(kind)' for Supplementary Element")
    }
    return reusableView
  }

  override func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    guard let momentArray = workingStory.moments else {
      CCLog.debug("No Moments for workingStory")
      return
    }

    if sourceIndexPath.item >= momentArray.count {
      CCLog.assert("sourceIndexPath.item >= momentArray.count ")
      return
    }

    let temp = workingStory.moments!.remove(at: sourceIndexPath.item)
    workingStory.moments!.insert(temp, at: destinationIndexPath.item)
  }
}


// MARK: - Collection View Flow Layout Delegate
extension MomentCollectionViewController: UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//    guard let momentArray = workingStory.moments else {
//      CCLog.debug("No Moments for workingStory")
//      return momentSizeDefault
//    }
//    if indexPath.row >= momentArray.count {
//      CCLog.assert("indexPath.row >= momentArray.count")
//      return momentSizeDefault
//    }
//    let moment = momentArray[indexPath.row]
    
    let height = collectionView.frame.height
    let width = height / FoodieGlobal.Constants.DefaultMomentAspectRatio
    return CGSize(width: width, height: height)
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
        
        guard let moments = self.workingStory.moments else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("No Moments for workingStory")
          }
          return
        }

        if indexPath.item >= moments.count {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
            CCLog.assert("Deleting a moment from an out of bound index")
          }
          return
        }

        if(moments.count == 1)
        {
          AlertDialog.present(from: self, title: "Delete Error", message: "Each story must contain at least one moment") { action in
            CCLog.info("User tried to remove the last Moment from Story")
          }
          return
        }

        let moment = moments[indexPath.item]

        // if the deleted item is the one with the thumnail, select next in the list
        if self.workingStory.thumbnailFileName == moment.thumbnailFileName {

          var rowIdx = indexPath.row + 1
          if(rowIdx >= moments.count)
          {
            rowIdx = indexPath.row - 1
          }

          // row is the index of the moment array
          self.setThumbnail(IndexPath(row: rowIdx, section: indexPath.section))
        }
 
        // Delete the Moment
        self.workingStory.moments!.remove(at: indexPath.item)
        
        moment.deleteRecursive(from: .both, type: .draft) { error in
          if let error = error {
            CCLog.warning("Failed to delete moments from pending delete moment lists: \(error)")
          }
        }

        // Pre-save the Story now that it's changed
        self.workingStory.saveDigest(to: .local, type: .draft) { error in
          if let error = error {
            AlertDialog.present(from: self, title: "Pre-Save Failed!", message: "Problem saving Story to Local Draft! Quitting or backgrounding the app might cause lost of the current Story under Draft!") { action in
              CCLog.assert("Pre-Saving Story to Draft Local Store Failed - \(error.localizedDescription)")
            }
          }
        }

        collectionView.deleteItems(at: [indexPath] )
      }
    }
  }
}