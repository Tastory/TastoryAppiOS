//
//  BranchVariables.swift
//  TastoryApp
//
//  Created by Howard Lee on 2017-12-21.
//  Copyright © 2017 Tastry. All rights reserved.
//

import Foundation

struct BranchVariables {
  
  // Facebook App ID is located in Info.plist, and also in URL types[0] -> URL schemes[0]
  // Please also verify the BundleID in the Xcode Project File pertains to your branch
  
  static let ParseAppId = "7oSLOsOtpxhPd6i0LQgSXE2U3c53CyCKrSongOBi"
  static let ParseClientKey = "apaYoewWV1U7PqncRSymmdRvlvYZiCKs1Yic7wFe"
  
  static let AwsS3BucketName = "tastry-dev-victor"
  static let AwsS3CloudfrontDomain = "https://dqeax91c6icyu.cloudfront.net/"
}
