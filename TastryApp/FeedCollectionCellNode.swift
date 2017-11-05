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
    fileprivate static let CoverTitleFontFraction: CGFloat = 0.052  // Of Constrained Size's Height
    fileprivate static let CoverTitleFontName: String = "Avenir-Medium"
    fileprivate static let CoverTitleMaxNumOfLines: UInt = 3
    fileprivate static let CoverTitleTextColor = UIColor.white
    fileprivate static let CoverTitleBackgroundBlackAlphas: [CGFloat] = [0.7, 0.0]
    fileprivate static let CoverTitleBackgroundBlackStops: [CGFloat] = [0.0, 1.0]
    fileprivate static let CoverTitleInsetWidthFraction: CGFloat = 0.050
    fileprivate static let CoverTitleInsetHeightFraction: CGFloat = 0.045
  }
  
  
  
  // MARK: - Private Instance Variable
  private let coverImageNode: ASNetworkImageNode
  private var coverTitleNode: ASTextNode?
  private var coverTitleBackgroundNode: ASDisplayNode?
  
  
  
  // MARK: - Public Instance Function
  init(story: FoodieStory) {
    guard let thumbnailFileName = story.thumbnailFileName else {
      CCLog.fatal("No Thumbnail Filename in Story \(story.getUniqueIdentifier())")
    }
    
    self.coverImageNode = ASNetworkImageNode()
    super.init()
    
    coverImageNode.url = FoodieFileObject.getS3URL(for: thumbnailFileName)
    coverImageNode.isLayerBacked = true
    
    if let coverTitle = story.title {
      coverTitleNode = ASTextNode()
      coverTitleNode!.attributedText = NSAttributedString(string: coverTitle)
      coverTitleNode!.maximumNumberOfLines = Constants.CoverTitleMaxNumOfLines
      coverTitleNode!.placeholderColor = Constants.CoverTitleTextColor
      coverTitleNode!.placeholderEnabled = true
      coverTitleNode!.isLayerBacked = true
      // Do we need this if we plan to drop shadows? coverTitleNode!.isOpaque = false
      
      // Create a gradient layer as title backing
      let backgroundColors = Constants.CoverTitleBackgroundBlackAlphas.map { UIColor.black.withAlphaComponent($0) }
      coverTitleBackgroundNode = GradientNode(startingAt: CGPoint(x: 0.5, y: 1.0),
                                              endingAt: CGPoint(x: 0.5, y: 0.0),
                                              with: backgroundColors,
                                              for: nil) //Constants.CoverTitleBackgroundBlackStops)
      coverTitleBackgroundNode!.isLayerBacked = true
      coverTitleBackgroundNode!.isOpaque = false
    }
    automaticallyManagesSubnodes = true
    enableSubtreeRasterization()
  }
  
    
  override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    
    let coverImageWrapperSpec = ASWrapperLayoutSpec(layoutElement: coverImageNode)
    
    // If there's no title, then this will be returned
    var finalLayoutSpec: ASLayoutSpec = coverImageWrapperSpec

    if let coverTitleNode = coverTitleNode {
      guard let coverTitleBackgroundNode = coverTitleBackgroundNode else {
        CCLog.fatal("FeedCellNode has titleNode but no titleBackgroundNode")
      }
      
      // Adjust the font size?
      if let attributedText = coverTitleNode.attributedText {
        guard let coverFont = UIFont(name: Constants.CoverTitleFontName,
                                     size: Constants.CoverTitleFontFraction * constrainedSize.max.height) else {
          CCLog.fatal("Cannot create UIFont with name \(Constants.CoverTitleFontName)")
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        coverTitleNode.attributedText = NSAttributedString(string: attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines),
                                                          attributes: [.font : coverFont,
                                                                       .foregroundColor : Constants.CoverTitleTextColor,
                                                                       .paragraphStyle : paragraphStyle])
      }
      
      // Inset the Title a little if needed
      let titleInsets = UIEdgeInsetsMake(Constants.CoverTitleInsetHeightFraction * constrainedSize.min.height,
                                         Constants.CoverTitleInsetWidthFraction * constrainedSize.min.width,
                                         Constants.CoverTitleInsetHeightFraction * constrainedSize.min.height,
                                         Constants.CoverTitleInsetWidthFraction * constrainedSize.min.width)
      let titleInsetSpec = ASInsetLayoutSpec(insets: titleInsets, child: coverTitleNode)
      
      // Overlay the Cover Title Node on the Title Background
      let titleOverlaySpec = ASBackgroundLayoutSpec(child: titleInsetSpec, background: coverTitleBackgroundNode)
      
      // Create Stack with Title Node
      let coverStackSpec = ASStackLayoutSpec(direction: .vertical, spacing: 5.0, justifyContent: .end, alignItems: .stretch, children: [titleOverlaySpec])
      
      // Overlay the Cover Stack in front of the Image Node
      let coverOverlaySpec = ASOverlayLayoutSpec(child: coverImageNode, overlay: coverStackSpec)
      
      finalLayoutSpec = coverOverlaySpec
    }
    
    return finalLayoutSpec
  }
}

