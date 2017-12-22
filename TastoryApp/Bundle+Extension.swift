//
//  Bundle+Extension.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-15.
//  Copyright © 2017 Tastory. All rights reserved.
//

import Foundation

extension Bundle {
  // Name of the app - title under the icon.
  var displayName: String? {
    return object(forInfoDictionaryKey: "CFBundleDisplayNameKey") as? String ??
      object(forInfoDictionaryKey: "CFBundleNameKey") as? String
  }
}
