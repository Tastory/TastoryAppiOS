//
//  URL+Extension.swift
//  TastryApp
//
//  Created by Howard Lee on 2017-10-25.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation

extension URL {
  
  static func addHttpIfNeeded(to linkText: String) -> String {
    var validHttpText = linkText
    let lowercaseText = linkText.lowercased()
    
    if !lowercaseText.hasPrefix("http://") && !lowercaseText.hasPrefix("https://") {
      validHttpText = "http://" + linkText
    }
    return validHttpText
  }
}
