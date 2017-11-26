//
//  MomentCollectionViewCell.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-04-22.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit


class MomentCollectionAddCell: UICollectionViewCell {
  
  // MARK: - Private Static Constants
  private struct Constants {
    static let CellCornerRadius: CGFloat = 5.0
    static let CellShadowColor = UIColor.black
    static let CellShadowOffset = CGSize(width: 0.0, height: 3.0)
    static let CellShadowRadius: CGFloat = 5.0
    static let CellShadowOpacity: Float = 0.25
  }

  
  // MARK: - IBOutlets
  @IBOutlet weak var addButton: UIButton!
  
  
  // MARK: - Public Instace Functions
  func configureLayers() {
    self.layer.masksToBounds = false
    self.layer.cornerRadius = Constants.CellCornerRadius
    self.layer.shadowColor = Constants.CellShadowColor.cgColor
    self.layer.shadowOffset = Constants.CellShadowOffset
    self.layer.shadowRadius = Constants.CellCornerRadius
    self.layer.shadowOpacity = Constants.CellShadowOpacity
    self.layer.shadowPath = UIBezierPath(roundedRect: layer.bounds, cornerRadius: layer.cornerRadius).cgPath
  }
}
