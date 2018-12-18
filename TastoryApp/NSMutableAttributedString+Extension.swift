//
//  NSMutableAttributedString+Extension.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-03-02.
//  Copyright © 2018 Tastry. All rights reserved.
//
import Foundation
import UIKit

extension NSMutableAttributedString {
  @discardableResult func bold14(_ text: String) -> NSMutableAttributedString {
    let boldString = NSMutableAttributedString(string:text, attributes: [NSAttributedString.Key.font : UIFont(name: "Raleway-SemiBold", size: 14)!, NSAttributedString.Key.strokeColor : FoodieGlobal.Constants.TextColor,NSAttributedString.Key.foregroundColor: FoodieGlobal.Constants.TextColor])
    append(boldString)

    return self
  }

  @discardableResult func bold12(_ text: String) -> NSMutableAttributedString {
    let boldString = NSMutableAttributedString(string:text, attributes: [NSAttributedString.Key.font : UIFont(name: "Raleway-SemiBold", size: 12)!, NSAttributedString.Key.strokeColor : FoodieGlobal.Constants.TextColor,NSAttributedString.Key.foregroundColor: FoodieGlobal.Constants.TextColor])
    append(boldString)
    return self
  }

  @discardableResult func normal(_ text: String) -> NSMutableAttributedString {
    let normal = NSAttributedString(string: text)
    append(normal)

    return self
  }
}
