//
//  BranchVariables.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-21.
//  Copyright © 2018 Tastory Lab Inc. All rights reserved.
//

import Foundation

struct BranchVariables {
  
  // Facebook App ID is located in Info.plist, and also in URL types[0] -> URL schemes[0]
  // Please also verify the BundleID in the Xcode Project File pertains to your branch
  
  static let ParseAppId = "L9lKtiKM6p7tltl32yfKs2ILLEJrnGpo1hwevYck"
  static let ParseClientKey = "JH02PgH9wThU0Lq6PJmP91i9PbnzfR2pJwfzGPMg"

  static let AwsS3BucketName = "tastry-dev-howard"
  static let AwsS3CloudfrontDomain = "https://d105mgh14bnrvo.cloudfront.net/"
}
