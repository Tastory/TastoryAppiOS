//
//  MarkupImageViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-29.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class MarkupImageViewController: UIViewController {
  
  var photoView: UIImageView?
  var previewPhoto: UIImage?
  
  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    guard let photo = previewPhoto else {
      print("DEBUG_PRINT: MarkupImageViewController.viewDidLoad - Shouldn't be here without a valid previewPhoto. Asserting")
      fatalError("Shouldn't be here without a valid previewPhoto")
    }
    
    photoView = UIImageView(frame: view.bounds)
    view.addSubview(photoView!)
    photoView?.image = photo
  }

  override func didReceiveMemoryWarning() {
      super.didReceiveMemoryWarning()
      // Dispose of any resources that can be recreated.
  }
  

  /*
  // MARK: - Navigation

  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
      // Get the new view controller using segue.destinationViewController.
      // Pass the selected object to the new view controller.
  }
  */

}
