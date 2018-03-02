//
//  SegmentedControl.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-03-02.
//  Copyright © 2018 Tastry. All rights reserved.
//

import UIKit

class SegmentedControl: UISegmentedControl {

  public var previousSelectedSegmentIndex: Int = 0

  override func willChangeValue(forKey key: String) {
    if key == #keyPath(selectedSegmentIndex) {
      previousSelectedSegmentIndex = selectedSegmentIndex
    }
    super.willChangeValue(forKey: key)
  }

}
