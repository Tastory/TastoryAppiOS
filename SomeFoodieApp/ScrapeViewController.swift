//
//  ScrapeViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-24.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit

class ScrapeViewController: UIViewController {

  @IBOutlet weak var blogURLfield: UITextField?
  
  @IBAction func startScraping(_ sender: UIButton) {
    
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config)
    
    guard let urlText = blogURLfield?.text else {
      // TODO: Ask the user to input something
      print("DEBUG_PRINT: startScraping - received empty URL input")
      return
    }

    guard let url = URL(string: urlText) else {
      // TODO: Tell user that the entered URL is not a valid URL
      print("DEBUG_PRINT: startScraping - received invalid URL input")
      return
    }
    
    let task = session.dataTask(with: url) { (data, response, error) in
          
      if let error = error {
        // TODO: Tell user about the error
        print("DEBUG_ERROR: startScraping - error = \(error)")
        return
      }
      
      if let response = response {
        print("DEBUG_PRINT: startScraping - response = \(response)")
      }
      
      guard let data = data else {
        // TODO: Something wrong with the returned data. How to handle?
        print("DEBUG_ERROR: startScraping - No valid data received")
        return
      }
      
      // Finally, lets play with the data
      
      
      
    }
        
    task.resume()
    
  }

  override func viewDidLoad() {
      super.viewDidLoad()

      // Do any additional setup after loading the view.
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
