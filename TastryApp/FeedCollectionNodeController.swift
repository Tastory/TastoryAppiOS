//
//  FeedCollectionNodeController.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-28.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation
import AsyncDisplayKit

final class FeedcollectionNodeController: ASViewController<ASDisplayNode>, ASCollectionDataSource, ASCollectionDelegate {
  
  // MARK: - Private Class Constants
  private struct Constants {
    static let DefaultColumns: CGFloat = 2.0
    static let DefaultPadding: CGFloat = 1.0
  }
  
  
  
  // MARK: - Public Instance Variable
  var storyQuery: FoodieQuery!
  var storyArray = [FoodieStory]()
  
  
  
  // MARK: - Private Instance Variable
  private var flowLayout: UICollectionViewLayout
  private var collectionNode: ASCollectionNode
  
  
  
  // MARK: - Public Instance Function
  init() {
    flowLayout = UICollectionViewFlowLayout()
    collectionNode = ASCollectionNode(collectionViewLayout: flowLayout)
    
    super.init(node: collectionNode)
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    CCLog.fatal("AsyncDisplayKit is not incompatible with Storyboards")
  }
  
  
  
  // MARK: - Node Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    collectionNode.delegate = self
    collectionNode.dataSource = self
  }
  
  
  // MARK: - ASCollectionDataSource Protocol Conformance
  func numberOfSections(in collectionNode: ASCollectionNode) -> Int {
    return 1
  }
  

  func collectionNode(_ collectionNode: ASCollectionNode, numberOfItemsInSection section: Int) -> Int {
    return storyArray.count
  }
  

  func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForItemAt indexPath: IndexPath) -> ASCellNodeBlock {
    return { return ASCellNode() }
  }
  
  
  func collectionNode(_ collectionNode: ASCollectionNode, nodeBlockForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> ASCellNodeBlock {
    return { return ASCellNode() }
  }
}
