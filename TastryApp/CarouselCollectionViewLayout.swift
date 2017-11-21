//
//  CarouselCollectionViewLayout
//  TastryApp
//
//  Created by Howard Lee on 2017-04-23.
//  Copyright © 2017 Tastry. All rights reserved.
//

import AsyncDisplayKit

class CarouselCollectionViewLayout: UICollectionViewFlowLayout {
  
  // MARK: - Constants
  struct Constants {
    static let DefaultCarouselScreenHeightFraction: CGFloat = 0.385  // Must match what's not covered by Touch Forwarding View in DiscoverViewController as seen in the Storyboard
    static let DefaultCellNodeAspectRatio = FoodieGlobal.Constants.DefaultMomentAspectRatio
    static let DefaultFeedBottomOffset: CGFloat = 24.0
    static let NonHighlightedItemAlpha: CGFloat = 0.9
    static let NonHighlightedItemScale: CGFloat = 0.9
    static let NonHighlightedItemOffsetFraction: CGFloat = 0.05  // This is deliberately set to half of 1 - NonHighlightedItemScale. This makes the cells perfectly pegged to be top
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

    // Let's just set these accordingly anyways
    self.itemSize = CGSize(width: cellNodeWidth, height: cellNodeHeight)
    self.estimatedItemSize = CGSize(width: cellNodeWidth, height: cellNodeHeight)
    return ASSizeRangeMake(self.itemSize)
  }
  
  
  func calculateSectionInset(for collectionBounds: CGRect, at section: Int) -> UIEdgeInsets {
    
    // Setting these here, hacky? Problem is if these are set too early, they conflict because
    // the previous layout is not fully invalidated. However if it's set too late, then how is
    // the layout going ot calculate all the cell positions?
    self.minimumLineSpacing = self.itemSize.width * Constants.InterLineSpacingFraction
    self.minimumInteritemSpacing = self.itemSize.width * Constants.InterLineSpacingFraction
    
    let carouselHeight = UIScreen.main.bounds.height*Constants.DefaultCarouselScreenHeightFraction
    let insetHeight = floor(collectionBounds.height - carouselHeight)
    let xInset = (collectionBounds.width - self.itemSize.width) / 2
    return UIEdgeInsetsMake(insetHeight, xInset, Constants.DefaultFeedBottomOffset, xInset)
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
