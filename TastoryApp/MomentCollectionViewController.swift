//
//  MomentCollectionViewController.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-04-28.
//  Copyright © 2017 Tastory Lab Inc. All rights reserved.
//

import UIKit

class MomentCollectionViewController: UICollectionViewController {
  
  // MARK: - Types & Enums
  enum MomentEditReadiness {
    case retrieving
    case pendingReady
  }
  
  
  // MARK: - Constants
  private struct Constants {
    static let MomentCellReuseId = "MomentCell"
    static let FooterElementReuseId = "MomentFooter"
    static let SectionInsetSpacing: CGFloat = 8
    static let InteritemSpacing: CGFloat = 8
  }

  
  // MARK: - Public Instance Variables
  var workingStory: FoodieStory!
  weak var cameraReturnDelegate: CameraReturnDelegate?
  weak var previewControlDelegate: PreviewControlDelegate?
  weak var containerVC: MarkupReturnDelegate?

  
  // MARK: - Private Instance Variables
  private var selectedViewCell: MomentCollectionViewCell?
  private var momentsPendingEditReady = [Int : MomentEditReadiness?]()
  private var readyMutex = SwiftMutex.create()
  private var outstandingStoryRetrievals = 0
  private var outstandingMutex = SwiftMutex.create()
  
  
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
              oldCell.thumbFrameLayer?.isHidden = true
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
    currentStory.thumbnailFileName = momentArray[indexPath.item].thumbnailFileName
    currentStory.thumbnail = momentArray[indexPath.item].thumbnail

    // Unhide the Thumbnail Frame to give feedback to user that this is the Story Thumbnail
    cell.thumbFrameLayer?.isHidden = false
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
            AlertDialog.present(from: self, title: "Pre-Save Failed!", message: "Problem saving Story to Local Draft! Quitting or backgrounding the app might cause lost of the current Story under Draft!") { _ in
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


    if(indexPath.item >= momentArray.count)
    {
      AlertDialog.present(from: self, title: "Tastory", message: "Error displaying media. Please try again") { _ in
        CCLog.fatal("Moment selection is out of bound")
      }
    }

    parent?.view.endEditing(true)
    
    let moment = momentArray[indexPath.item]
    let storyboard = UIStoryboard(name: "Compose", bundle: nil)
    guard let viewController = storyboard.instantiateFoodieViewController(withIdentifier: "MarkupViewController") as? MarkupViewController else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
        CCLog.fatal("ViewController initiated not of MarkupViewController Class!!")
      }
      return
    }
    viewController.markupReturnDelegate = markupReturnVC

    guard let media = moment.media else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
        CCLog.assert("Nil media object in moment")
      }
      return
    }

    viewController.mediaObj = media
    viewController.editMomentObj = moment
    viewController.addToExistingStoryOnly = true
    self.present(viewController, animated: true)
  }

  private func updateMomentCell(to cell: UICollectionViewCell? = nil, in collectionView: UICollectionView, forItemAt indexPath: IndexPath) {

    guard let momentArray = workingStory.moments else {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { [unowned self] _ in
        CCLog.assert("No Moments for workingStory \(self.workingStory.getUniqueIdentifier())")
      }
      return
    }

    if let reusableCell = cell as? MomentCollectionViewCell {
      let moment = momentArray[indexPath.item]

      if reusableCell.indexPath == indexPath {
        if self.workingStory.thumbnailFileName != nil, self.workingStory.thumbnailFileName == moment.thumbnailFileName {
          reusableCell.thumbFrameLayer?.isHidden = false
        } else {
          reusableCell.thumbFrameLayer?.isHidden = true
        }
        reusableCell.activitySpinner.remove()
        if(!workingStory.isEditStory) {
          reusableCell.deleteButton.isHidden = false
        }
      }
    } else {
      //CCLog.verbose("No cell provided or found for story \(self.workingStory.getUniqueIdentifier()))!!!")
      collectionView.reloadItems(at: [indexPath])
    }
  }

  
  
  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.accessibilityIdentifier = "momentCollectionView"

    guard let collectionView = self.collectionView else {
      CCLog.fatal("collection view from momentViewController is nil")
    }
    
    if workingStory.isEditStory {
      // retrieve story only when in edit mode
      previewControlDelegate?.enablePreviewButton(false)
      
      guard let moments = workingStory.moments else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("Working Story moments = nil")
        }
        return
      }
      
      outstandingStoryRetrievals = moments.count
      var storyIndex = 0
      
      for moment in moments {
        
        // Mark Moment not ready to Edit
        let indexCopy = storyIndex
        momentsPendingEditReady[storyIndex] = .retrieving
        
        let retrieveOperation = StoryOperation(with: .moment, on: workingStory, for: storyIndex) { error in
          if let error = error {
            CCLog.warning("Retrieving story into draft failed with error: \(error.localizedDescription)")
            return
          }
          
          moment.saveWhole(to: .local, type: .draft, for: nil) { error in
            if let error = error {
              AlertDialog.present(from: self, title: "Draft Error", message: error.localizedDescription) { _ in
                CCLog.assert("Saving story into draft failed with error: \(error.localizedDescription)")
              }
              return
            }
            
            var shouldUpdateMomentCell = false
            
            // If there's outstanding Colleciton View Cell to be enabled, do so now. Otherwise just mark yourself ready for edit
            SwiftMutex.lock(&self.readyMutex)
            guard let momentReadiness = self.momentsPendingEditReady[indexCopy] else {
              AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
                CCLog.fatal("No Moment Pending Edit Ready after Save to Draft")
              }
              return
            }
            
            if momentReadiness == .pendingReady { shouldUpdateMomentCell = true }
            
            self.momentsPendingEditReady.removeValue(forKey: indexCopy)
            SwiftMutex.unlock(&self.readyMutex)
            
            if shouldUpdateMomentCell {
              self.updateMomentCell(in: collectionView, forItemAt: IndexPath(item: indexCopy, section: 0))
            }
            
            SwiftMutex.lock(&self.outstandingMutex)
            self.outstandingStoryRetrievals -= 1
            if self.outstandingStoryRetrievals == 0 {
              self.previewControlDelegate?.enablePreviewButton(true)
              let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.reorderMoment(_:)))
              collectionView.addGestureRecognizer(longPressGesture)
            }
            SwiftMutex.unlock(&self.outstandingMutex)
          }
        }
      
        FoodieFetch.global.queue(retrieveOperation, at: .high)
        storyIndex += 1
      }
    } else {
      let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(reorderMoment(_:)))
      collectionView.addGestureRecognizer(longPressGesture)
    }
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
    
    guard let momentArray = workingStory.moments else {
      CCLog.fatal("No Moments for workingStory \(workingStory.getUniqueIdentifier())")
    }
    
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.MomentCellReuseId, for: indexPath) as! MomentCollectionViewCell

    cell.accessibilityLabel = "momentCollectionViewCell"
    cell.accessibilityTraits = UIAccessibilityTraitButton
    cell.isAccessibilityElement = true
    cell.isUserInteractionEnabled = true


    // Configure Default Cell State
    cell.configureLayers(frame: cell.bounds)
    
    if cell.thumbImageNode.view.gestureRecognizers == nil {
      let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.thumbnailGesture(_:)))
      tapRecognizer.numberOfTapsRequired = 1
      cell.thumbImageNode.view.isUserInteractionEnabled = true
      cell.thumbImageNode.view.addGestureRecognizer(tapRecognizer)
      
      let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.editMoment(_:)))
      doubleTapRecognizer.numberOfTapsRequired = 2
      cell.thumbImageNode.view.addGestureRecognizer(doubleTapRecognizer)
      tapRecognizer.require(toFail: doubleTapRecognizer)
    }
    
    cell.indexPath = indexPath
    cell.delegate = self
    cell.deleteButton.isHidden = true
    cell.thumbFrameLayer?.isHidden = true

    if indexPath.item >= momentArray.count {
      AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
        CCLog.assert("Moment Array for Story \(self.workingStory.getUniqueIdentifier()) index out of range - indexPath.item \(indexPath.item) >= momentArray.count \(momentArray.count)")
      }
      return cell
    }
    
    let moment = momentArray[indexPath.item]
    
    if let thumbnailBuffer = moment.thumbnail?.imageMemoryBuffer {
      cell.thumbImageNode.url = nil
      cell.thumbImageNode.image = UIImage(data: thumbnailBuffer)
    
    } else {
      guard let thumbnailFileName = moment.thumbnailFileName else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { alert in
          CCLog.assert("No Thumbnail Filename for Moment \(moment.getUniqueIdentifier())")
        }
        return cell
      }
      cell.thumbImageNode.image = nil
      cell.thumbImageNode.url = FoodieFileObject.getS3URL(for: thumbnailFileName)
    }

    var momentReadyToEdit = true
    
    SwiftMutex.lock(&readyMutex)
    if let momentPending = momentsPendingEditReady[indexPath.item]  {
      if momentPending == .retrieving {
        momentsPendingEditReady[indexPath.item] = .pendingReady
      }
      momentReadyToEdit = false
    }
    SwiftMutex.unlock(&readyMutex)
    
    if momentReadyToEdit {
      updateMomentCell(to: cell, in: collectionView, forItemAt: indexPath)
    } else {
      cell.activitySpinner.apply()
    }
    return cell
  }

  
  override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    var reusableView: UICollectionReusableView!
    
    switch kind {
    case UICollectionElementKindSectionFooter:
        guard let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: Constants.FooterElementReuseId, for: indexPath) as? MomentAddFooterReusableView else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
            CCLog.assert("UICollectionElementKindSectionFooter dequeued is not MomentAddFooterReusableView")
          }
          return reusableView
        }
        footerView.addMomentButton.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        footerView.addMomentButton.isHidden = workingStory.isEditStory

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
}


  
// MARK: - Collection View Flow Layout Delegate
extension MomentCollectionViewController: UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

    let height = collectionView.bounds.height - 2*Constants.SectionInsetSpacing
    let width = height * FoodieGlobal.Constants.DefaultMomentAspectRatio
    return CGSize(width: width, height: height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return Constants.InteritemSpacing
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return Constants.InteritemSpacing
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
    let height = collectionView.bounds.height - 2*Constants.InteritemSpacing
    let width = height * FoodieGlobal.Constants.DefaultMomentAspectRatio + Constants.SectionInsetSpacing
    return CGSize(width: width, height: collectionView.bounds.height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsetsMake(Constants.SectionInsetSpacing, Constants.SectionInsetSpacing, Constants.SectionInsetSpacing, Constants.SectionInsetSpacing)
  }
}



extension MomentCollectionViewController: MomentCollectionViewCellDelegate {

  func deleteMoment(sourceCell cell: MomentCollectionViewCell) {

    // make sure you get confirmation from user before deleting 
    AlertDialog.presentConfirm(from: self, title: "Deleting a moment", message: "Do you want to delete this moment?"){ [unowned self] _ in

      guard let collectionView = self.collectionView else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
          CCLog.assert("collection view is nil")
        }
        return
      }

      if let indexPath = collectionView.indexPath(for: cell) {
        
        guard let moments = self.workingStory.moments else {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            CCLog.assert("No Moments for workingStory")
          }
          return
        }

        if indexPath.item >= moments.count {
          AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .internalTryAgain) { _ in
            CCLog.assert("Deleting a moment from an out of bound index")
          }
          return
        }

        if(moments.count == 1)
        {
          AlertDialog.present(from: self, title: "Delete Error", message: "Each story must contain at least one moment") { _ in
            CCLog.info("User tried to remove the last Moment from Story")
          }
          return
        }

        let moment = moments[indexPath.item]

        // if the deleted item is the one with the thumnail, select next in the list
        if self.workingStory.thumbnailFileName == moment.thumbnailFileName {

          var itemIdx = indexPath.item + 1
          if(itemIdx >= collectionView.visibleCells.count)
          {
            itemIdx = indexPath.item - 1
          }

          // row is the index of the moment array
          self.setThumbnail(IndexPath(item: itemIdx, section: indexPath.section))
        }
 
        // Delete the Moment
        self.workingStory.moments!.remove(at: indexPath.item)

        var location: FoodieObject.StorageLocation = .both

        // when editing, we only want to delete the local copy not the server copy
        if(moment.isEditMoment) {
          location = .local
        }

        _ = moment.deleteWhole(from: location, type: .draft) { error in
          if let error = error {
            CCLog.warning("Failed to delete moments from pending delete moment lists: \(error)")
          }
        }

        // Pre-save the Story now that it's changed
        _ = self.workingStory.saveDigest(to: .local, type: .draft) { error in
          if let error = error {
            AlertDialog.present(from: self, title: "Pre-Save Failed!", message: "Problem saving Story to Local Draft! Quitting or backgrounding the app might cause lost of the current Story under Draft!") { _ in
              CCLog.assert("Pre-Saving Story to Draft Local Store Failed - \(error.localizedDescription)")
            }
          }
        }

        collectionView.deleteItems(at: [indexPath] )
      }
    }
  }
}


