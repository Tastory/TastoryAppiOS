//
//  MomentCollectionLayout.swift
//  EatellyApp
//
//  Created by Howard Lee on 2017-04-25.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit


// This implements stretchy header for the Moment Collection View
class MomentCollectionLayout: UICollectionViewFlowLayout {
  
  var maximumHeaderStretchWidth: CGFloat = 0
  
  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    
    guard let layoutAttributes = super.layoutAttributesForElements(in: rect) else {
      return nil
    }
    
    for attributes in layoutAttributes {
      if let elementKind = attributes.representedElementKind, elementKind == UICollectionElementKindSectionHeader {
        var frame = attributes.frame
        frame.size.width = maximumHeaderStretchWidth + 1
        frame.origin.x = -maximumHeaderStretchWidth
        attributes.frame = frame
      }
    }
    return layoutAttributes
  }
  
  override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    return false
  }
}
