//
//  MomentAddFooterReusableView
//  TastryApp
//
//  Created by Howard Lee on 2017-04-22.
//  Copyright © 2017 Tastry. All rights reserved.
//


import UIKit

class MomentAddFooterReusableView: UICollectionReusableView {
  
  // MARK: - Private Static Constants
  private struct Constants {
    static let CellCornerRadius: CGFloat = 5.0
    static let CellShadowColor = UIColor.black
    static let CellShadowOffset = CGSize(width: 0.0, height: 3.0)
    static let CellShadowRadius: CGFloat = 5.0
    static let CellShadowOpacity: Float = 0.15
  }
  
  
  // MARK: - Private Instance Variables
  private var isInitialLayout = true
  
  
  // MARK: - IBOutlets
  @IBOutlet weak var addMomentButton: UIButton!
  
  
  // MARK: - Public Instance Functions
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if isInitialLayout {
      isInitialLayout = false
      
      addMomentButton.layer.masksToBounds = false
      addMomentButton.layer.cornerRadius = Constants.CellCornerRadius
      addMomentButton.layer.shadowColor = Constants.CellShadowColor.cgColor
      addMomentButton.layer.shadowOffset = Constants.CellShadowOffset
      addMomentButton.layer.shadowRadius = Constants.CellCornerRadius
      addMomentButton.layer.shadowOpacity = Constants.CellShadowOpacity

      addMomentButton.layer.shadowPath = UIBezierPath(roundedRect: addMomentButton.layer.bounds, cornerRadius: addMomentButton.layer.cornerRadius).cgPath
    }
  }
}
