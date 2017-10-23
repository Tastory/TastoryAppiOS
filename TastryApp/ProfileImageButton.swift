//
//  ProfileImageButton.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-22.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class ProfileImageButton: UIButton {

  var borderColor: UIColor = UIColor.white {
    didSet {
      layer.borderColor = borderColor.cgColor
    }
  }
  
  var cornerRadius: CGFloat = 5.0 {
    didSet {
      layer.cornerRadius = cornerRadius
    }
  }
  
  var borderWidth: CGFloat = 2.0 {
    didSet {
      layer.borderWidth = borderWidth
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    clipsToBounds = true
  }
}
