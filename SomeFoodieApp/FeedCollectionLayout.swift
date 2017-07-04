//
//  FeedCollectionLayout.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-05-29.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

protocol FeedCollectionLayoutDelegate: AnyObject {
  
  func collectionView(_ collectionView: UICollectionView, heightForImageAtIndexPath indexPath: IndexPath, withWidth width: CGFloat) -> CGFloat
  
  func collectionView(_ collectionView: UICollectionView, heightForDescriptionAtIndexPath indexPath: IndexPath, withWidth width: CGFloat) -> CGFloat
}


class FeedCollectionLayoutAttributes: UICollectionViewLayoutAttributes {
  
  var imageHeight: CGFloat = 0
  
  override func copy(with zone: NSZone?) -> Any {
    let copy = super.copy(with: zone) as! FeedCollectionLayoutAttributes
    copy.imageHeight = imageHeight
    return copy
  }
  
  override func isEqual(_ object: Any?) -> Bool {
    if let attributes = object as? FeedCollectionLayoutAttributes {
      if attributes.imageHeight == imageHeight {
        return super.isEqual(object)
      }
    }
    return false
  }
}


class FeedCollectionLayout: UICollectionViewLayout {
  
  weak var delegate: FeedCollectionLayoutDelegate?
  var numberOfColumns = 0
  var cellPadding: CGFloat = 0
  
  var cache = [FeedCollectionLayoutAttributes]()
  fileprivate var contentHeight: CGFloat = 0
  fileprivate var width: CGFloat {
    get {
      let insets = collectionView!.contentInset
      return collectionView!.bounds.width - (insets.left + insets.right)
    }
  }
  
  override var collectionViewContentSize : CGSize {
    return CGSize(width: width, height: contentHeight)
  }
  
  override class var layoutAttributesClass : AnyClass {
    return FeedCollectionLayoutAttributes.self
  }
  
  override func prepare() {
    
    guard let delegate = delegate else {
      return
    }
    
    if cache.isEmpty {
      let columnWidth = width / CGFloat(numberOfColumns)
      
      var xOffsets = [CGFloat]()
      for column in 0..<numberOfColumns {
        xOffsets.append(CGFloat(column) * columnWidth)
      }
      
      var yOffsets = [CGFloat](repeating: 0, count: numberOfColumns)
      
      var column = 0
      for item in 0..<collectionView!.numberOfItems(inSection: 0) {
        let indexPath = IndexPath(item: item, section: 0)
        
        let width = columnWidth - (cellPadding * 2)
        let imageHeight = delegate.collectionView(collectionView!, heightForImageAtIndexPath: indexPath, withWidth: width)
        let descriptionHeight = delegate.collectionView(collectionView!, heightForDescriptionAtIndexPath: indexPath, withWidth: width)
        let height = cellPadding + imageHeight + descriptionHeight + cellPadding
        
        let frame = CGRect(x: xOffsets[column], y: yOffsets[column], width: columnWidth, height: height)
        let insetFrame = frame.insetBy(dx: cellPadding, dy: cellPadding)
        let attributes = FeedCollectionLayoutAttributes(forCellWith: indexPath)
        attributes.frame = insetFrame
        attributes.imageHeight = imageHeight
        cache.append(attributes)
        contentHeight = max(contentHeight, frame.maxY)
        yOffsets[column] = yOffsets[column] + height
        column = column >= (numberOfColumns - 1) ? 0 : column + 1
      }
    }
  }
  
  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    var layoutAttributes = [UICollectionViewLayoutAttributes]()
    for attributes in cache {
      if attributes.frame.intersects(rect) {
        layoutAttributes.append(attributes)
      }
    }
    return layoutAttributes
  }
}
