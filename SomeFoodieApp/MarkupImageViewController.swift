//
//  MarkupImageViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-29.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import Parse

class MarkupImageViewController: UIViewController {
  
  var photoView: UIImageView?
  var previewPhoto: UIImage?
  
  @IBOutlet weak var saveButton: UIButton?
  
  @IBAction func saveButtonAction(_ sender: UIButton) {
    
    let momentObj = FoodieMoment()
    
    momentObj.media = PFFile(data: UIImageJPEGRepresentation(photo, ), contentType: "photo") // TODO: Compresion on upload/download, + server side work?
    // momentObj["mediaURL"] // Can be photo or video
    // momentObj[["Markups"]] // Array of captions
    // momentObj["aspectRatio"]
    // momentObj["size"] // Is this necassary? Re-interpolate if this is not 'nativish' size?
    // momentObj[["tag"]]
    // momemtObj["category"]
    // momentObj["describes"] // Dish vs Interior vs Exterior vs ...?
    // momentObj["detailedDescription"] // Dish name, interior specifics, exterior specifics?
    // momentObj["views"]
    // momentObj["clickthroughs"]
    //
    //
    
//    testObject["foo"] = "bar"
//    testObject.saveInBackground { (success, error) in
//      if success {
//        print("Object has been saved!")
//      } else if let errorUnwrapped = error {
//        print("Save failed - \(errorUnwrapped.localizedDescription)")
//      } else {
//        print("Save failed but no valid error description")
//      }
//    }
    
  }
  
  // MARK: - View Controller Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    guard let photo = previewPhoto else {
      print("DEBUG_PRINT: MarkupImageViewController.viewDidLoad - Shouldn't be here without a valid previewPhoto. Asserting")
      fatalError("Shouldn't be here without a valid previewPhoto")
    }
    
    // Display the photo
    photoView = UIImageView(frame: view.bounds)
    view.addSubview(photoView!)
    view.sendSubview(toBack: photoView!)
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
