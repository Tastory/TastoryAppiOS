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
    static let DefaultCarouselScreenHeightFraction: CGFloat = 0.375  // Must match what's not covered by Touch Forwarding View in DiscoverViewController as seen in the Storyboard
    static let DefaultCellNodeAspectRatio = FoodieGlobal.Constants.DefaultMomentAspectRatio
    static let DefaultFeedNodeMargin: CGFloat = 5.0
    static let DefaultFeedBottomOffset: CGFloat = 16.0
    static let NonHighlightedItemAlpha: CGFloat = 0.9
    static let NonHighlightedItemScale: CGFloat = 0.90
    static let NonHighlightedItemOffsetFraction: CGFloat = 0.05
    static let InterLineSpacingFraction: CGFloat = -0.025
  }
  
  
  
  // MARK: - Public Instance Function
  
  override init() {
    super.init()
    self.scrollDirection = .horizontal
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    CCLog.fatal("init(coder:) has not been implemented")
  }
  
  
  func calculateConstrainedSize(for collectionBounds: CGRect) -> ASSizeRange {
    var cellNodeHeight = UIScreen.main.bounds.height*Constants.DefaultCarouselScreenHeightFraction-Constants.DefaultFeedBottomOffset
    cellNodeHeight = floor(cellNodeHeight)  // Take the floor to avoid messes
    let cellNodeWidth = cellNodeHeight * Constants.DefaultCellNodeAspectRatio
    
    // TOOD: Do we need to allow for a smaller size here so the biggest cell is in the middle? Or do we do that as part of the Layout Attributes?
    
    // Let's just set these accordingly anyways
    self.itemSize = CGSize(width: cellNodeWidth, height: cellNodeHeight)
    self.estimatedItemSize = CGSize(width: cellNodeWidth, height: cellNodeHeight)
    return ASSizeRangeMake(self.itemSize)
  }
  
  
  func calculateSectionInset(for collectionBounds: CGRect, at section: Int) -> UIEdgeInsets {
    let carouselHeight = UIScreen.main.bounds.height*Constants.DefaultCarouselScreenHeightFraction
    let insetHeight = floor(collectionBounds.height - carouselHeight)
    return UIEdgeInsetsMake(insetHeight, 0.0, Constants.DefaultFeedBottomOffset, Constants.DefaultFeedNodeMargin)
  }
  
  
  func changeLayoutAttributes(_ attributes: UICollectionViewLayoutAttributes) {
    let collectionCenter = collectionView!.frame.size.width/2
    let normalizedCenter = attributes.center.x - collectionView!.contentOffset.x
    
    let maxDistance = self.itemSize.width + self.minimumLineSpacing
    let distance = min(abs(collectionCenter - normalizedCenter), maxDistance)
    let ratio = (maxDistance - distance)/maxDistance
    
    let standardItemAlpha = Constants.NonHighlightedItemAlpha
    let standardItemScale = Constants.NonHighlightedItemScale
    let standardItemOffset = self.itemSize.height * Constants.NonHighlightedItemOffsetFraction
    
    let alpha = ratio * (1 - standardItemAlpha) + standardItemAlpha
    let scale = ratio * (1 - standardItemScale) + standardItemScale
    let offset = (1 - ratio) * standardItemOffset
      
    let scaleTransform = CATransform3DMakeScale(scale, scale, 1)
    let offsetTransform = CATransform3DMakeTranslation(0.0, -offset, 0.0)
      
    attributes.alpha = alpha
    attributes.transform3D = CATransform3DConcat(scaleTransform, offsetTransform)
    attributes.zIndex = Int(alpha * 10)
  }
  
  
  override func prepare() {
    super.prepare()
    
    self.collectionView!.decelerationRate = UIScrollViewDecelerationRateFast
    let collectionBounds = collectionView!.bounds
    
    self.itemSize = calculateConstrainedSize(for: collectionBounds).max
    self.estimatedItemSize = calculateConstrainedSize(for: collectionBounds).max
    self.minimumLineSpacing = itemSize.width * Constants.InterLineSpacingFraction
    self.minimumInteritemSpacing = itemSize.width * Constants.InterLineSpacingFraction
    
    let carouselHeight = UIScreen.main.bounds.height*Constants.DefaultCarouselScreenHeightFraction
    let insetHeight = floor(collectionBounds.height - carouselHeight)
    let xInset = (collectionBounds.width - self.itemSize.width) / 2
    self.sectionInset = UIEdgeInsetsMake(insetHeight, xInset, Constants.DefaultFeedBottomOffset, xInset)
  }
  
  
  override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    return true
  }
  

  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    let attributes = super.layoutAttributesForElements(in: rect)
    var attributesCopy = [UICollectionViewLayoutAttributes]()
    
    for itemAttributes in attributes! {
      let itemAttributesCopy = itemAttributes.copy() as! UICollectionViewLayoutAttributes
      changeLayoutAttributes(itemAttributesCopy)
      attributesCopy.append(itemAttributesCopy)
    }
    return attributesCopy
  }
  
  
  override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
    let layoutAttributes = self.layoutAttributesForElements(in: collectionView!.bounds)
    let center = collectionView!.bounds.size.width / 2
    let proposedContentOffsetCenterOrigin = proposedContentOffset.x + center
    let closest = layoutAttributes!.sorted { abs($0.center.x - proposedContentOffsetCenterOrigin) < abs($1.center.x - proposedContentOffsetCenterOrigin) }.first ?? UICollectionViewLayoutAttributes()
    let targetContentOffset = CGPoint(x: floor(closest.center.x - center), y: proposedContentOffset.y)
    
    return targetContentOffset
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

