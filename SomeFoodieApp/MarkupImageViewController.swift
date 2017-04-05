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
    
    guard let photo = previewPhoto else {
      print("DEBUG_ERROR: MarkupImageViewController.saveButtonAction - previewPhoto = nil")
      return
    }
    
    guard let imageData = UIImageJPEGRepresentation(photo, FoodieMoment.GlobalConstants.jpegCompressionQuality) else  {
      print("DEBUG_ERROR: MarkupImageViewController.saveButtonAction - Cannot create JPEG representation")
      return
    }
    
    momentObj.media = PFFile(data: imageData, contentType: "photo") // TODO: Compresion on upload/download, + server side work?
    momentObj.mediaType = FoodieMoment.mediaType.photo.rawValue
    momentObj.aspectRatio = Double(photo.size.width / photo.size.height)  // TODO: Are we just always gonna deal with full res?
    momentObj.width = Int(Double(photo.size.width))
    
// TODO: Implement with Markup and Scrape features
//    momentObj.markup
//    momentObj.tags
    
// TODO: Implement along with User Login
//    momentObj.author
    
// TODO: Implement along with Foursquare integration
//    momentObj.eatery
//    momentObj.categories
//    momentObj.type
//    momentObj.attribute
    
// TODO: Impelemnt with display views
//    momentObj.views
//    momentObj.clickthroughs

    if FoodieJournal.current() != nil {
      // Ask the user if they want to add this image to the current Journal or start a new Journal, or cancel
      newOrAddAlert = UIAlertController
      // If new Journal, ask if user want to save the current, discard, or cancel the whole thing
    } else {
      FoodieJournal.new(saveCurrent: false, errorCallback: <#T##((Bool, Error?) -> Void)?##((Bool, Error?) -> Void)?##(Bool, Error?) -> Void#>)
    }
    
    // If not cancelled, lets pass the object to the Journal Entry View
    PFUser.current()
    
    // Lets jump to the Journal Entry View
  }
  
  
  // MARK: - Public Function
  func newJournalResultCallback(success: Bool, error: Error?) -> Void {
    
    if success {
      print("DEBUG_LOG: MarkupImageViewController.newJournalResultCallback - Success")
      return
    } else {
      
    }
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
