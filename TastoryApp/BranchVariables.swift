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
  
  static let ParseAppId = "GJjSZxaEgtjTv0fhpEIjO4OL6giDoCoIS70cpVgM"
  static let ParseClientKey = "eJG3LnDRawWG3WKi4SQvvWFt1hiGd2GId2iItzUT"
  
  static let AwsS3BucketName = "tastry-master"
  static let AwsS3CloudfrontDomain = "https://d2zy9a8xd3cswc.cloudfront.net/"
}
