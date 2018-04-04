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
  
  static let ParseAppId = "50SE7cRLJJEk67dKe2N2WYmmRrPiBVQPDbTjJcSk"
  static let ParseClientKey = "YFWvsmyTy1y4rJrH16ZbGhGNNAi1JxECsG9YvBDT"
  
  static let AwsS3BucketName = "tastry"
  static let AwsS3CloudfrontDomain = "https://d114pxxl4yxol3.cloudfront.net/"
}
