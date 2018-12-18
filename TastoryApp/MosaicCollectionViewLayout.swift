//
//  MosaicCollectionViewLayout
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AsyncDisplayKit


protocol MosaicCollectionViewLayoutDelegate: ASCollectionDelegate {
  func collectionView(_ collectionView: UICollectionView, layout: MosaicCollectionViewLayout, originalItemSizeAtIndexPath: IndexPath) -> CGSize
}



class MosaicCollectionViewLayout: UICollectionViewLayout {
  
  // MARK: - Constants
  
  struct Constants {
    static let DefaultColumns: Int = 2
    static let DefaultCellNodeAspectRatio = FoodieGlobal.Constants.DefaultMomentAspectRatio
    static let DefaultFeedNodeMargin: CGFloat = 5.0
    static let ColumnHeightOffsetAsFractionOfFirstItemHeight: [CGFloat] = [0.0, 0.5]
  }
  
  
  
  // MARK: - Public Instance Variables
  
  weak var delegate : MosaicCollectionViewLayoutDelegate?
  
  var numberOfColumns: Int
  var columnSpacing: CGFloat
  var sectionInset: UIEdgeInsets
  var interItemSpacing: UIEdgeInsets
  var headerHeight: CGFloat
  var columnHeights: [[CGFloat]]?
  var itemAttributes = [[UICollectionViewLayoutAttributes]]()
  var headerAttributes = [UICollectionViewLayoutAttributes]()
  var allAttributes = [UICollectionViewLayoutAttributes]()
  
  
  // MARK: - Public Static Functions
  static func defaultColumnWidth(for collectionWidth: CGFloat) -> CGFloat {
    let columnSpacing = Constants.DefaultFeedNodeMargin
    let numberOfColumns = Constants.DefaultColumns
    return (collectionWidth - 2*columnSpacing - CGFloat(numberOfColumns - 1)*columnSpacing) / CGFloat(numberOfColumns)
  }
  
  
  // MARK: - Public Instance Functions
  
  required override init() {
    self.numberOfColumns = Constants.DefaultColumns
    self.columnSpacing = Constants.DefaultFeedNodeMargin
    self.sectionInset = UIEdgeInsets.init(top: 0.0, left: columnSpacing, bottom: 0.0, right: columnSpacing)
    self.interItemSpacing = UIEdgeInsets.init(top: columnSpacing, left: 0, bottom: columnSpacing, right: 0)
    self.headerHeight = 0.0
    super.init()
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    CCLog.fatal("init(coder:) has not been implemented")
  }
  
  
  func calculateConstrainedSize(for collectionBounds: CGRect) -> ASSizeRange {
    let collectionWidth = collectionBounds.width
    var cellNodeWidth = (collectionWidth - 2*columnSpacing - CGFloat(numberOfColumns - 1)*columnSpacing) / CGFloat(numberOfColumns)
    if numberOfColumns == 3 { cellNodeWidth = floor(cellNodeWidth) }  // Weird problem when the itemWidth is .3 repeat.
    let cellNodeHeight = cellNodeWidth/Constants.DefaultCellNodeAspectRatio
    
    // Let's just set these accordingly anyways
    return ASSizeRangeMake(CGSize(width: cellNodeWidth, height: cellNodeHeight))
  }
  
  
  func calculateSectionInset(for collectionBounds: CGRect, at section: Int) -> UIEdgeInsets {
    return UIEdgeInsets.init(top: 0.0, left: columnSpacing, bottom: collectionBounds.height - calculateConstrainedSize(for: collectionBounds).max.height, right: columnSpacing)
  }
  
  
  override func prepare() {
    super.prepare()
    guard let collectionView = self.collectionView else {
      CCLog.assert("No Collection View when trying to prepare Layout")
      return
    }
    
    columnHeights = []
    itemAttributes = []
    headerAttributes = []
    allAttributes = []
    
    var top: CGFloat = 0
    
    let numberOfSections: NSInteger = collectionView.numberOfSections
    
    for section in 0 ..< numberOfSections {
      let numberOfItems = collectionView.numberOfItems(inSection: section)
      sectionInset = calculateSectionInset(for: collectionView.bounds, at: section)
      
      top += sectionInset.top
      
      if (headerHeight > 0) {
        let headerSize: CGSize = self.headerSizeForSection(section: section)
        
        let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, with: NSIndexPath(row: 0, section: section) as IndexPath)
        
        attributes.frame = CGRect(x: sectionInset.left, y: top, width: headerSize.width, height: headerSize.height)
        headerAttributes.append(attributes)
        allAttributes.append(attributes)
        top = attributes.frame.maxY
      }
      
      columnHeights?.append([]) //Adding new Section
      for columnIndex in 0 ..< self.numberOfColumns {
        let firstIndexPath = IndexPath(item: 0, section: section)
        let firstItemSize = itemSizeAtIndexPath(indexPath: firstIndexPath)
        let firstItemHeight = firstItemSize.height
        let heightForColumn = top + firstItemHeight * Constants.ColumnHeightOffsetAsFractionOfFirstItemHeight[columnIndex]
        self.columnHeights?[section].append(heightForColumn)
      }
      
      let columnWidth = self.columnWidthForSection(section: section)
      
      itemAttributes.append([])
      for idx in 0 ..< numberOfItems {
        let columnIndex: Int = self.shortestColumnIndexInSection(section: section)
        let indexPath = IndexPath(item: idx, section: section)
        
        let itemSize = self.itemSizeAtIndexPath(indexPath: indexPath);
        let xOffset = sectionInset.left + (columnWidth + columnSpacing) * CGFloat(columnIndex)
        let yOffset = columnHeights![section][columnIndex]
        
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        
        attributes.frame = CGRect(x: xOffset, y: yOffset, width: itemSize.width, height: itemSize.height)
        
        columnHeights?[section][columnIndex] = attributes.frame.maxY + interItemSpacing.bottom
        
        itemAttributes[section].append(attributes)
        allAttributes.append(attributes)
      }
      
      let columnIndex: Int = self.tallestColumnIndexInSection(section: section)
      top = (columnHeights?[section][columnIndex])! - interItemSpacing.bottom + sectionInset.bottom
      
      for idx in 0 ..< columnHeights![section].count {
        columnHeights![section][idx] = top
      }
    }
  }
  
  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]?
  {
    var includedAttributes: [UICollectionViewLayoutAttributes] = []
    // Slow search for small batches
    for attribute in allAttributes {
      if (attribute.frame.intersects(rect)) {
        includedAttributes.append(attribute)
      }
    }
    return includedAttributes
  }
  
  
  override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes?
  {
    guard indexPath.section < itemAttributes.count,
      indexPath.item < itemAttributes[indexPath.section].count
      else {
        return nil
    }
    return itemAttributes[indexPath.section][indexPath.item]
  }
  
  
  override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes?
  {
    if (elementKind == UICollectionView.elementKindSectionHeader) {
      return headerAttributes[indexPath.section]
    }
    return nil
  }
  
  
  override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    if (!(self.collectionView?.bounds.size.equalTo(newBounds.size))!) {
      return true;
    }
    return false;
  }
  
  
  override var collectionViewContentSize: CGSize
  {
    var height: CGFloat = 0
    if ((columnHeights?.count)! > 0) {
      if (columnHeights?[(columnHeights?.count)!-1].count)! > 0 {
        height = (columnHeights?[(columnHeights?.count)!-1][0])!
      }
    }
    return CGSize(width: self.collectionView!.bounds.size.width, height: height)
  }
  
  
  func widthForSection (section: Int) -> CGFloat
  {
    return self.collectionView!.bounds.size.width - sectionInset.left - sectionInset.right;
  }
  
  
  func columnWidthForSection(section: Int) -> CGFloat
  {
    return (self.widthForSection(section: section) - ((CGFloat(numberOfColumns - 1)) * columnSpacing)) / CGFloat(numberOfColumns)
  }
  
  
  func itemSizeAtIndexPath(indexPath: IndexPath) -> CGSize
  {
    var size = CGSize(width: self.columnWidthForSection(section: indexPath.section), height: 0)
    let originalSize = self.delegate!.collectionView(self.collectionView!, layout:self, originalItemSizeAtIndexPath:indexPath)
    if (originalSize.height > 0 && originalSize.width > 0) {
      size.height = originalSize.height / originalSize.width * size.width
    }
    return size
  }
  
  
  func headerSizeForSection(section: Int) -> CGSize
  {
    return CGSize(width: self.widthForSection(section: section), height: headerHeight)
  }
  

  func tallestColumnIndexInSection(section: Int) -> Int
  {
    var index: Int = 0;
    var tallestHeight: CGFloat = 0;
    _ = columnHeights?[section].enumerated().map { (idx,height) in
      if (height > tallestHeight) {
        index = idx;
        tallestHeight = height
      }
    }
    return index
  }
  
  
  func shortestColumnIndexInSection(section: Int) -> Int
  {
    var index: Int = 0;
    var shortestHeight: CGFloat = CGFloat.greatestFiniteMagnitude
    _ = columnHeights?[section].enumerated().map { (idx,height) in
      if (height < shortestHeight) {
        index = idx;
        shortestHeight = height
      }
    }
    return index
  }
}



class MosaicCollectionViewLayoutInspector: NSObject, ASCollectionViewLayoutInspecting
{
  func collectionView(_ collectionView: ASCollectionView, constrainedSizeForNodeAt indexPath: IndexPath) -> ASSizeRange {
    let layout = collectionView.collectionViewLayout as! MosaicCollectionViewLayout
    return ASSizeRangeMake(layout.itemSizeAtIndexPath(indexPath: indexPath), layout.itemSizeAtIndexPath(indexPath: indexPath))
  }
  
  func collectionView(_ collectionView: ASCollectionView, constrainedSizeForSupplementaryNodeOfKind: String, at atIndexPath: IndexPath) -> ASSizeRange
  {
    let layout = collectionView.collectionViewLayout as! MosaicCollectionViewLayout
    return ASSizeRange.init(min: layout.headerSizeForSection(section: atIndexPath.section), max: layout.headerSizeForSection(section: atIndexPath.section))
  }
  
  /**
   * Asks the inspector for the number of supplementary sections in the collection view for the given kind.
   */
  func collectionView(_ collectionView: ASCollectionView, numberOfSectionsForSupplementaryNodeOfKind kind: String) -> UInt {
    if (kind == UICollectionView.elementKindSectionHeader) {
      return UInt((collectionView.dataSource?.numberOfSections!(in: collectionView))!)
    } else {
      return 0
    }
  }
  
  /**
   * Asks the inspector for the number of supplementary views for the given kind in the specified section.
   */
  func collectionView(_ collectionView: ASCollectionView, supplementaryNodesOfKind kind: String, inSection section: UInt) -> UInt {
    if (kind == UICollectionView.elementKindSectionHeader) {
      return 1
    } else {
      return 0
    }
  }
  
  func scrollableDirections() -> ASScrollDirection {
    return ASScrollDirectionVerticalDirections;
  }
}
