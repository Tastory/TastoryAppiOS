//
//  CarouselCollectionViewLayout
//  TastryApp
//
//  Created by Howard Lee on 2017-04-23.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AsyncDisplayKit

protocol CarouselCollectionViewLayoutDelegate: ASCollectionDelegate {

}



class CarouselCollectionViewLayout: UICollectionViewFlowLayout {
  
  // MARK: - Constants
  struct Constants {
    static let DefaultCarouselHeightFraction: CGFloat = 0.5
    static let DefaultCellNodeAspectRatio = FoodieGlobal.Constants.DefaultMomentAspectRatio
    static let DefaultFeedNodeMargin: CGFloat = 5.0
    static let DefaultFeedBottomOffset: CGFloat = 16.0
  }
  
  
  
  // MARK: - Public Instance Function
  
  override init() {
    super.init()
    self.scrollDirection = .horizontal
    let feedNodeMargin = Constants.DefaultFeedNodeMargin
    self.minimumInteritemSpacing = feedNodeMargin
    self.minimumLineSpacing = feedNodeMargin
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    CCLog.fatal("init(coder:) has not been implemented")
  }
  
  
  func calculateConstrainedSize(for collectionBounds: CGRect) -> ASSizeRange {
    let cellNodeHeight = collectionBounds.height * Constants.DefaultCarouselHeightFraction
    let cellNodeWidth = cellNodeHeight * Constants.DefaultCellNodeAspectRatio
    
    // TOOD: Do we need to allow for a smaller size here so the biggest cell is in the middle? Or do we do that as part of the Layout Attributes?
    
    // Let's just set these accordingly anyways
    self.itemSize = CGSize(width: cellNodeWidth, height: cellNodeHeight)
    self.estimatedItemSize = CGSize(width: cellNodeWidth, height: cellNodeHeight)
    return ASSizeRangeMake(self.itemSize)
  }
  
  
  func calculateSectionInset(for collectionBounds: CGRect, at section: Int) -> UIEdgeInsets {
    return UIEdgeInsetsMake((collectionBounds.height*Constants.DefaultCarouselHeightFraction)-Constants.DefaultFeedBottomOffset,
                            0.0, Constants.DefaultFeedBottomOffset, 0.0)
  }
}



//class CarouselCollectionViewLayoutInspector: NSObject, ASCollectionViewLayoutInspecting
//{
//  func collectionView(_ collectionView: ASCollectionView, constrainedSizeForNodeAt indexPath: IndexPath) -> ASSizeRange {
//    let layout = collectionView.collectionViewLayout as! CarouselCollectionViewLayout
//    CCLog.verbose("ItemSize Width: \(layout._itemSizeAtIndexPath(indexPath: indexPath).width), ItemSize Height: \(layout._itemSizeAtIndexPath(indexPath: indexPath).height)")
//    return ASSizeRangeMake(layout._itemSizeAtIndexPath(indexPath: indexPath), layout._itemSizeAtIndexPath(indexPath: indexPath))
//  }
//
//  func collectionView(_ collectionView: ASCollectionView, constrainedSizeForSupplementaryNodeOfKind: String, at atIndexPath: IndexPath) -> ASSizeRange
//  {
//    let layout = collectionView.collectionViewLayout as! CarouselCollectionViewLayout
//    return ASSizeRange.init(min: layout._headerSizeForSection(section: atIndexPath.section), max: layout._headerSizeForSection(section: atIndexPath.section))
//  }
//
//  /**
//   * Asks the inspector for the number of supplementary sections in the collection view for the given kind.
//   */
//  func collectionView(_ collectionView: ASCollectionView, numberOfSectionsForSupplementaryNodeOfKind kind: String) -> UInt {
//    if (kind == UICollectionElementKindSectionHeader) {
//      return UInt((collectionView.dataSource?.numberOfSections!(in: collectionView))!)
//    } else {
//      return 0
//    }
//  }
//
//  /**
//   * Asks the inspector for the number of supplementary views for the given kind in the specified section.
//   */
//  func collectionView(_ collectionView: ASCollectionView, supplementaryNodesOfKind kind: String, inSection section: UInt) -> UInt {
//    if (kind == UICollectionElementKindSectionHeader) {
//      return 1
//    } else {
//      return 0
//    }
//  }
//
//  func scrollableDirections() -> ASScrollDirection {
//    return ASScrollDirectionVerticalDirections;
//  }
//}

