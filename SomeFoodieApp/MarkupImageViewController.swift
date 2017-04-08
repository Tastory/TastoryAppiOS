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
  
  @IBOutlet weak var saveButton: UIButton?
  
  @IBAction func saveButtonAction(_ sender: UIButton) {
    
    let momentObj = FoodieMoment()
    
    guard let photo = previewPhoto else {
      // TODO: ErrorHandle - Inform user of error and offer chance to retry
      DebugPrint.error("Unexpected. previewPhoto is nil")
      return
    }
  
    do {
      
      try momentObj.setMedia(withPhoto: photo)
      
    } catch let thrown as FoodieError {
      
      switch thrown.error {
        
      case FoodieError.Code.Moment.setMediaWithPhotoImageNil.rawValue:
        // TODO: ErrorHandle - Inform user of error and offer chance to retry
        DebugPrint.error("caught Moment.setMediaWithPhotoImageNil")
        return
        
      case FoodieError.Code.Moment.setMediaWithPhotoJpegRepresentationFailed.rawValue:
        // TODO: ErrorHandle - Inform user of error and offer chance to retry
        DebugPrint.error("caught Moment.setMediaWithPhotoJpegRepresentationFailed")
        return
      
      default:
        // TODO: ErrorHandle - Inform user of error and offer chance to retry
        DebugPrint.error("Unexpected Foodie Error: \(thrown.localizedDescription)")
        return
      }
      
    } catch let thrown {
      // TODO: ErrorHandle - Inform user of error and offer chance to retry
      DebugPrint.error(thrown.localizedDescription)
      return
    }
    
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

    momentObj.saveInBackground { (success, error) in
      if success {
        DebugPrint.log("Save Test Success")
      } else if let error = error {
        DebugPrint.error("Save Test Error")
        DebugPrint.error("Error.localizedDescription: \(error.localizedDescription)")
      }
    }
    
    if FoodieJournal.current() != nil {
      // Ask the user if they want to add this image to the current Journal or start a new Journal, or cancel
      //let newOrAddAlert = UIAlertController
      // If new Journal, ask if user want to save the current, discard, or cancel the whole thing
    } else {
      //FoodieJournal.new(saveCurrent: false, errorCallback: <#T##((Bool, Error?) -> Void)?##((Bool, Error?) -> Void)?##(Bool, Error?) -> Void#>)
    }
    
    // If not cancelled, lets pass the object to the Journal Entry View
    //PFUser.current()
    
    // Lets jump to the Journal Entry View
  }
  
  
  // MARK: - Public Function
  func newJournalResultCallback(success: Bool, error: Error?) -> Void {
    
    if success {
      DebugPrint.log("MarkupImageViewController.newJournalResultCallback - Success")
      return
    } else {
      
    }
  }
  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    guard let photo = previewPhoto else {
      // TODO: ErrorHandle -Inform user of error and offer chance to retry?
      DebugPrint.assert("Shouldn't be here without a valid previewPhoto")
      return
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
