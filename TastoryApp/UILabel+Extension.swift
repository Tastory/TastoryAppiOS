//
//  UILabel+Extension.swift
//  TastoryApp
//
//  Created by Howard Lee on 2018-02-24.
//  Copyright © 2018 Tastory Lab Inc. All rights reserved.
//

import UIKit

extension UILabel {
  func addCharactersSpacing(spacing: CGFloat, text: String) {
    let attributedString = NSMutableAttributedString(string: text)
    attributedString.addAttribute(.kern, value: spacing, range: NSMakeRange(0, text.count))
    self.attributedText = attributedString
  }
}
