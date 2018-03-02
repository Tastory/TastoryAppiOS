//
//  String+Extension.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-03-02.
//  Copyright © 2018 Tastry. All rights reserved.
//

import UIKit

extension String {

  // find the index of a substring
  func index(of string: String, options: CompareOptions = .caseInsensitive) -> Index? {
    return range(of: string, options: options)?.lowerBound
  }
}
