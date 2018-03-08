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

  func indicesOf(string: String, options: CompareOptions = .caseInsensitive) -> [Int] {
    var indices = [Int]()
    var searchStartIndex = self.startIndex

    while searchStartIndex < self.endIndex,
      let range = self.range(of: string, options: options, range: searchStartIndex..<self.endIndex),
      !range.isEmpty
    {
      let index = distance(from: self.startIndex, to: range.lowerBound)
      indices.append(index)
      searchStartIndex = range.upperBound
    }

    return indices
  }
}
