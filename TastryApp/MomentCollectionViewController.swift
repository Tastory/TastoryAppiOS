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
    static let interitemSpacing: CGFloat = 2
    static let headerFooterToCellWidthRatio: CGFloat = 3/4
  }

  // MARK: - Public Instance Variables
  var workingStory: FoodieStory!
  var cameraReturnDelegate: CameraReturnDelegate!
  var containerVC: MarkupReturnDelegate?

  // MARK: - Private Instance Variables
  fileprivate var selectedViewCell: MomentCollectionViewCell?

  // MARK: - Private Instance Functions
  @objc private func openCamera() {
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "CameraViewController") as! CameraViewController
    viewController.addToExistingStoryOnly = true
    viewController.cameraReturnDelegate = cameraReturnDelegate
    self.present(viewController, animated: true)
  }

  private func setThumbnail(_ indexPath: IndexPath) {

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
    currentStory.thumbnail = momentArray[indexPath.row].thumbnail

    // Unhide the Thumbnail Frame to give feedback to user that this is the Story Thumbnail
    cell.thumbFrameView.isHidden = false
  }

  @objc private func thumbnailGesture(_ sender: UIGestureRecognizer) {

    guard let collectionView = self.collectionView else {
      CCLog.fatal("collection view from momentViewController is nil")
    }

    let point = sender.location(in: collectionView)

    guard let indexPath = collectionView.indexPathForItem(at: point) else {
      // invalid index path selected just return
      return
    }
    setThumbnail(indexPath)

    // save journal
    FoodieStory.preSave(nil) { (error) in
      if error != nil {  // preSave should have logged the error, so skipping that here.
        AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .saveTryAgain)
        return
      }
    }
  }

  @objc private func reorderMoment(_ gesture: UILongPressGestureRecognizer) {

    guard let collectionView = collectionView else {
      CCLog.assert("Error unwrapping the collectionView from moment view controller is nil")
      return
    }

    switch(gesture.state) {

    case UIGestureRecognizerState.began:
      guard let selectedIndexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
        break
      }
      collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
      selectedViewCell = collectionView.cellForItem(at: selectedIndexPath) as? MomentCollectionViewCell

      guard let selectedCell = selectedViewCell else {
        CCLog.assert("Can't get momentCollectionViewCell from collection view")
        return
      }

      selectedCell.wobble()
    case UIGestureRecognizerState.changed:
      collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
    case UIGestureRecognizerState.ended:
      collectionView.endInteractiveMovement()

      if(selectedViewCell != nil) {
        selectedViewCell!.stopWobble()

        guard let story = workingStory else {
          CCLog.assert("workingStory is nil")
          return
        }

        // Pre-save the Story now that it's changed
        _ = story.saveDigest(to: .local, type: .draft) { error in
          if let error = error {
            AlertDialog.present(from: self, title: "Pre-Save Failed!", message: "Problem saving Story to Local Draft! Quitting or backgrounding the app might cause lost of the current Story under Draft!") { action in
              CCLog.assert("Pre-Saving Story to Draft Local Store Failed - \(error.localizedDescription)")
            }
          }
        }
      }

    default:
      collectionView.cancelInteractiveMovement()
    }
  }

  @objc private func editMoment(_ sender: UIGestureRecognizer)
  {

    guard let collectionView = self.collectionView else {
      CCLog.fatal("collection view from momentViewController is nil")
    }

    let point = sender.location(in: collectionView)

    guard let indexPath = collectionView.indexPathForItem(at: point) else {
      // invalid index path selected just return
      return
    }

    guard let momentArray = workingStory?.moments else {
      CCLog.fatal("No moments in current working story.")
    }

    guard let markupReturnVC = containerVC else {
      CCLog.fatal("Story Entry VC does not have a Container VC")
    }


    if(indexPath.row >= momentArray.count)
    {
      AlertDialog.present(from: self, title: "TastryApp", message: "Error displaying media. Please try again") { action in
        CCLog.fatal("Moment selection is out of bound")
      }
    }

    let moment = momentArray[indexPath.row]
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
        CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
      }
      return
    }
    viewController.markupReturnDelegate = markupReturnVC

    guard let media = moment.media else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { action in
        CCLog.assert("Nil media object in moment")
      }
      return
    }

    viewController.mediaObj = media
    viewController.editMomentObj = moment
    viewController.addToExistingStoryOnly = true
    viewController.setTransition(presentTowards: .up, dismissTowards: .down, dismissIsDraggable: false)
    self.present(viewController, animated: true)

  }
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    guard let collectionView = self.collectionView else {
      CCLog.fatal("collection view from momentViewController is nil")
    }

    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(reorderMoment(_:)))
    collectionView.addGestureRecognizer(longPressGesture)
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
      CCLog.verbose("No Moments in Working Story")
      return 0
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
    
    cell.activityIndicator.hidesWhenStopped = true
    cell.activityIndicator.startAnimating()
    cell.deleteButton.isHidden = true


    _  = moment.retrieveRecursive(from: .both, type: .cache) { (error) in

      if let error = error {
        AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .saveTryAgain) { action in
          CCLog.assert("Error retrieving story into cache caused by: \(error.localizedDescription)")
        }
      }

      _ = moment.saveRecursive(to: .local, type: .draft) { (error) in
        if let error = error {
          AlertDialog.standardPresent(from: self, title: .genericSaveError, message: .saveTryAgain) { action in
            CCLog.assert("Saving story into draft caused by: \(error.localizedDescription)")
          }
        }
      }

      guard let thumbnailObj = moment.thumbnail else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
          CCLog.assert("No Thumbnail Object for Moment \(moment.getUniqueIdentifier())")
        }
        return
      }

      guard let thumbnailFileName = moment.thumbnailFileName else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
          CCLog.assert("No Thumbnail Filename for Moment \(moment.getUniqueIdentifier())")
        }
        return
      }

      if thumbnailObj.imageMemoryBuffer == nil {
        do {
          try thumbnailObj.imageMemoryBuffer = Data(contentsOf: FoodieFileObject.Constants.DraftStoryMediaFolderUrl.appendingPathComponent(thumbnailFileName))
        } catch {
          AlertDialog.present(from: self, title: "File Read Error", message: "Cannot read image file from local flash storage") { action in
            CCLog.assert("Cannot read image file \(thumbnailFileName)")
          }
        }
      }

      if(cell.viewButton.gestureRecognizers == nil) {

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.thumbnailGesture(_:)))
        tapRecognizer.numberOfTapsRequired = 1
        cell.viewButton.isUserInteractionEnabled = true
        cell.viewButton.addGestureRecognizer(tapRecognizer)

        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.editMoment(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        cell.viewButton.addGestureRecognizer(doubleTapRecognizer)
        tapRecognizer.require(toFail: doubleTapRecognizer)
      }

      DispatchQueue.main.async {

        // referencing a cell using the original indexpath doesnt seem to work here just reuse cell reference in the first place
        if(cell.momentThumb.image == nil) {
          cell.momentThumb.image = UIImage(data: moment.thumbnail!.imageMemoryBuffer!)
        }

        // Should Thumbnail frame be hidden?
        cell.createFrameLayer()
        if self.workingStory.thumbnailFileName != nil, self.workingStory.thumbnailFileName == moment.thumbnailFileName {
          cell.thumbFrameView.isHidden = false
        } else {
          cell.thumbFrameView.isHidden = true
        }

        cell.delegate = self
        cell.activityIndicator.stopAnimating()
        cell.deleteButton.isHidden = false
      }
    }

    return cell
  }


  override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    var reusableView: UICollectionReusableView!

    switch kind {
    case UICollectionElementKindSectionHeader:
      reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: Constants.headerElementReuseId, for: indexPath)
    case UICollectionElementKindSectionFooter:
      guard let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: Constants.footerElementReuseId, for: indexPath) as? MomentFooterReusableView else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { action in
          CCLog.assert("UICollectionElementKindSectionFooter dequeued is not MomentFooterReusableView")
        }
        return reusableView
      }
      footerView.addMomentButton.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
      reusableView = footerView
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
  
  
  // MARK: - Scroll View Delegate Conformance
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if scrollView.contentOffset.x <= 0 {
      openCamera()
    }
  }
}


// MARK: - Collection View Flow Layout Delegate
extension MomentCollectionViewController: UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

    guard let momentHeightUnwrapped = momentHeight else {
      CCLog.fatal("nil momentHeight in Moment Collection View Controller")
    }

    let height = momentHeightUnwrapped - 2*Constants.interitemSpacing
    let width = height / FoodieGlobal.Constants.DefaultMomentAspectRatio
    return CGSize(width: width, height: height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return Constants.interitemSpacing
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return Constants.interitemSpacing
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {

    guard let momentHeightUnwrapped = momentHeight else {
      CCLog.fatal("nil momentHeight in Moment Collection View Controller")
    }

    let height = momentHeightUnwrapped - 2*Constants.interitemSpacing
    let width = height / FoodieGlobal.Constants.DefaultMomentAspectRatio * Constants.headerFooterToCellWidthRatio
    
    // Now we know the width, also set the Collection View Content Inset here
    collectionView.contentInset = UIEdgeInsetsMake(0.0, -width, 0.0, 0.0)
    return CGSize(width: width, height: height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {

    guard let momentHeightUnwrapped = momentHeight else {
      CCLog.fatal("nil momentHeight in Moment Collection View Controller")
    }

    let height = momentHeightUnwrapped - 2*Constants.interitemSpacing
    let width = height / FoodieGlobal.Constants.DefaultMomentAspectRatio * Constants.headerFooterToCellWidthRatio
    return CGSize(width: width, height: height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsetsMake(Constants.interitemSpacing, Constants.interitemSpacing, Constants.interitemSpacing, Constants.interitemSpacing)
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

        var location: FoodieObject.StorageLocation = .both

        // when editing, we only want to delete the local copy not the server copy
        if(moment.objectId != nil) {
          location = .local
        }

        moment.deleteRecursive(from: location, type: .draft) { error in
          if let error = error {
            CCLog.warning("Failed to delete moments from pending delete moment lists: \(error)")
          }
        }

        // Pre-save the Story now that it's changed
        _ = self.workingStory.saveDigest(to: .local, type: .draft) { error in
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


