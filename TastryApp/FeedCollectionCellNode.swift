//
//  FeedCollectionCellNode.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-28.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation
import AsyncDisplayKit

class FeedCollectionCellNode: ASCellNode {
  
  // MARK: - Constants
  struct Constants {
    fileprivate static let CoverPhotoAspectRatio: CGFloat = FoodieGlobal.Constants.DefaultMomentAspectRatio
    fileprivate static let CoverTitleMaxFontSize: CGFloat = 17.0
    fileprivate static let CoverTitleMinFontSize: CGFloat = 15.0
    fileprivate static let CoverTitleFontName: String = "Avenir-Medium"
    fileprivate static let CoverTitleBackgroundBlackAlpha: CGFloat = 0.3
    fileprivate static let CoverTitleInsets = UIEdgeInsetsMake(15.0, 15.0, 15.0, 15.0)
    fileprivate static let CoverStackInsets = UIEdgeInsetsMake(3.0, 3.0, 3.0, 3.0)
  }
  
  
  private static let gradientBackgroundNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 1.0),
                                                           endingAt: CGPoint(x: 0.5, y: 0.0),
                                                           with: [UIColor.black.withAlphaComponent(Constants.CoverTitleBackgroundBlackAlpha), UIColor.clear])
  
  
  // MARK: - Private Instance Variable
  private let story: FoodieStory
  private let coverImageNode: ASNetworkImageNode
  private let numOfColumns: Int
  private let interCardInsetSize: CGFloat
  private var coverTitleNode: ASTextNode?
  private var coverTitleBackgroundNode: ASDisplayNode?
  
  
  
  // MARK: - Public Instance Variables
  var coverTitleMaxFontSize: CGFloat = Constants.CoverTitleMaxFontSize
  var coverTitleMinFontSize: CGFloat = Constants.CoverTitleMinFontSize
  var coverTitleFontName: String = Constants.CoverTitleFontName
  
  
  
  // MARK: - Public Instance Function
  init(story: FoodieStory, numOfColumns: Int, interCardInsetSize: CGFloat) {
    guard let thumbnailFileName = story.thumbnailFileName else {
      CCLog.fatal("No Thumbnail Filename in Story \(story.getUniqueIdentifier())")
    }
    
    self.story = story
    self.coverImageNode = ASNetworkImageNode()
    self.numOfColumns = numOfColumns
    self.interCardInsetSize = interCardInsetSize
    super.init()
    
    coverImageNode.url = FoodieFileObject.getS3URL(for: thumbnailFileName)
    coverImageNode.isLayerBacked = true
    
    if let coverTitle = story.title {
      guard let coverFont = UIFont(name: coverTitleFontName, size: coverTitleMaxFontSize) else {
        CCLog.fatal("Cannot create UIFont with name \(coverTitleFontName)")
      }
      coverTitleNode = ASTextNode()
      coverTitleNode!.attributedText = NSAttributedString(string: coverTitle, attributes: [.font : coverFont, .foregroundColor : UIColor.darkGray])
      coverTitleNode!.isLayerBacked = true
      //coverTitleNode!.isOpaque = false
      
      // Create a gradient layer as title backing
      coverTitleBackgroundNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 1.0),
                                              endingAt: CGPoint(x: 0.5, y: 0.0),
                                              with: [UIColor.black.withAlphaComponent(Constants.CoverTitleBackgroundBlackAlpha), UIColor.clear])//FeedCollectionCellNode.gradientBackgroundNode
      coverTitleBackgroundNode!.isLayerBacked = true
      coverTitleBackgroundNode!.isOpaque = false
    }
    
    automaticallyManagesSubnodes = true
  }
  
  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    
    let coverImageWrapperSpec = ASWrapperLayoutSpec(layoutElement: coverImageNode)
    
    // If there's no title, then this will be returned
    var finalLayoutSpec: ASLayoutSpec = coverImageWrapperSpec

    if let coverTitleNode = coverTitleNode {
      guard let coverTitleBackgroundNode = coverTitleBackgroundNode else {
        CCLog.fatal("FeedCellNode has titleNode but no titleBackgroundNode")
      }
      
      // Inset the Title a little if needed
      let titleInsetSpec = ASInsetLayoutSpec(insets: Constants.CoverTitleInsets, child: coverTitleNode)
      
      // Overlay the Cover Title Node on the Title Background
      let titleOverlaySpec = ASOverlayLayoutSpec(child: coverTitleBackgroundNode, overlay: titleInsetSpec)
      
      // Create Stack with Title Node
      let coverStackSpec = ASStackLayoutSpec.vertical()
      coverStackSpec.justifyContent = .end
      coverStackSpec.alignItems = .center
      coverStackSpec.children = [titleOverlaySpec]
      
      // Create Spec to inset the Cover Stack if needed
      //let coverStackInsetSpec = ASInsetLayoutSpec(insets: Constants.CoverStackInsets, child: coverStackSpec)
      
      // Overlay the Cover Stack in front of the Image Node
      let coverOverlaySpec = ASOverlayLayoutSpec(child: coverImageWrapperSpec, overlay: coverStackSpec) // coverStackInsetSpec)
      
      finalLayoutSpec = ASWrapperLayoutSpec(layoutElement: coverTitleBackgroundNode) // coverOverlaySpec
    }
    
    return finalLayoutSpec
  }
}

