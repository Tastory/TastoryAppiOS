//
//  MomentCollectionViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-28.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
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


  // MARK: - View Controller Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    guard let collectionViewUnwrapped = collectionView else {
      DebugPrint.fatal("nil collectionView in Moment Collection View Controller")
    }

    guard let momentHeightUnwrapped = momentHeight else {
      DebugPrint.fatal("nil momentHeight in Moment Collection View Controller")
    }
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    self.automaticallyAdjustsScrollViewInsets = false

    collectionViewUnwrapped.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    // Setup Dimension Variables
    momentWidthDefault = momentHeightUnwrapped/(16/9)
    momentSizeDefault = CGSize(width: momentWidthDefault, height: momentHeightUnwrapped)

    // Setup the Moment Colleciton Layout
    let layout = collectionViewLayout as! MomentCollectionLayout
    layout.minimumLineSpacing = 0 //Constants.interitemSpacing
    layout.minimumInteritemSpacing = Constants.interitemSpacing
    layout.headerReferenceSize = CGSize(width: 1, height: momentHeightUnwrapped)
    layout.footerReferenceSize = momentSizeDefault
    layout.itemSize = momentSizeDefault
    layout.estimatedItemSize = momentSizeDefault
    layout.sectionInset = UIEdgeInsets(top: 0, left: Constants.interitemSpacing,
                                       bottom: 0, right: Constants.interitemSpacing)
    layout.maximumHeaderStretchWidth = momentWidthDefault
    
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
      DebugPrint.log("No Moments for workingJournal")
      return cell
    }
    
    if indexPath.row >= momentArray.count {
      DebugPrint.assert("indexPath.row >= momentArray.count")
      return cell
    }
    
    let moment = momentArray[indexPath.row]
    
    // TODO: Download the moment if not in memory
//    moment.fetchIfNeededInBackground { (object, error) in
//      
//      if let err = error {
//        DebugPrint.fatal("Error fetching moment: \(err)")
//      }
//      
//      guard let moment = object as? FoodieMoment else {
//        DebugPrint.fatal("fetched Object is not a FoodieMoment")
//      }
//      
//      guard let file = moment.media else {
//        DebugPrint.fatal("Moment Media is nil")
//      }
//      
//      file.getDataInBackground { (data, error) in
//        
//        if let err = error {
//          DebugPrint.fatal("Error getting media data: \(err)")
//        }
//        
//        guard let imageData = data else {
//          DebugPrint.fatal("nil data obtained from media file")
//        }
//        
//        if let image = UIImage(data: imageData) {
//          
//          if let currentCell = collectionView.cellForItem(at: indexPath) as? MomentCollectionViewCell {
//            currentCell.momentButton.setImage(image, for: .normal)
//          } else {
//            DebugPrint.log("MomentCollectionViewCell not visible or indexPath is out of range")
//          }
//          
//        } else {
//          DebugPrint.fatal("Error getting image from image data")
//        }
//      }
//    }
    
    // TODO: Download the thumbnail if not in memory
    
    let thumbnail = UIImage(data: moment.thumbnailObject!.imageMemoryBuffer!)
    
    cell.momentButton.setImage(thumbnail, for: .normal)
  
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
      DebugPrint.fatal("Unrecognized Kind '\(kind)' for Supplementary Element")
    }
    return reusableView
  }
}


// MARK: - Collection View Flow Layout Delegate
extension MomentCollectionViewController: UICollectionViewDelegateFlowLayout {
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    
    guard let momentArray = workingJournal.moments else {
      DebugPrint.log("No Moments for workingJournal")
      return momentSizeDefault
    }
    
    if indexPath.row >= momentArray.count {
      DebugPrint.assert("indexPath.row >= momentArray.count")
      return momentSizeDefault
    }
    
    let moment = momentArray[indexPath.row]
    
//    guard let thumbnailObject = moment.thumbnailObject else {
//      DebugPrint.assert("Unexpected, moment.thumbnailObject == nil")
//      return momentSizeDefault
//    }
    

    let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
    
    DebugPrint.verbose("Layout Section Inset: \(flowLayout.sectionInset)")
    DebugPrint.verbose("Layout Minimum Line Spacing: \(flowLayout.minimumLineSpacing)")
    DebugPrint.verbose("Layout Minimum Interitem Spacing: \(flowLayout.minimumInteritemSpacing)")
    DebugPrint.verbose("CollectionView Content Size:\(collectionView.contentSize)")
    DebugPrint.verbose("CollectionView Content Inset: \(collectionView.contentInset)")
    
    let height = min(momentHeight!, collectionView.contentSize.height)

    DebugPrint.verbose("Returning height of sizeForItemAt row \(indexPath.row) to be \(height)")
    
    return CGSize(width: height-1/CGFloat(moment.aspectRatio), height: height-1)
  }
}
