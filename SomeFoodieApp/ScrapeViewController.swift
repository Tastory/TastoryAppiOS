//
//  ScrapeViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-03-24.
//  Copyright © 2017 SomeFoodieCompany. All rights reserved.
//

import UIKit
import Kanna

class ScrapeViewController: UIViewController {

  @IBOutlet weak var blogURLfield: UITextField?

  @IBOutlet weak var cssField: UITextField?
  
  @IBAction func startScraping(_ sender: UIButton) {
    
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config)
    
    guard let urlText = blogURLfield?.text else {
      // TODO: Ask the user to input something
      DebugPrint.error("startScraping - Received empty URL input")
      return
    }

    guard let url = URL(string: urlText) else {
      // TODO: Tell user that the entered URL is not a valid URL
      DebugPrint.error("Received invalid URL input")
      return
    }
    
    let task = session.dataTask(with: url) { (data, response, error) in
          
      if let error = error {
        // TODO: Tell user about the error
        DebugPrint.error("\(error)")
        return
      }
      
      DebugPrint.log("Current thread is: \(Thread.current)")
      DebugPrint.log("Current thread is \(Thread.isMainThread ? "" : "not ")main thread")
      
      guard let response = response as? HTTPURLResponse else {
        // TODO: Non-HTTP resposne received. How to handle??
        DebugPrint.error("Non-HTTP response received")
        return
      }
      
      DebugPrint.log("response = \(response)")
      
      guard let data = data else {
        // TODO: Something wrong with the returned data. How to handle?
        DebugPrint.error("No valid data received")
        return
      }
      
      // Finally, lets play with the data
      if response.statusCode == 200 {
        guard let myHTMLString = String(data: data, encoding: String.Encoding.utf8) else {
          // TODO: Returned data is not UTF8. How to handle?
          DebugPrint.error("Returned data is not UTF8")
          return
        }
        
        guard let doc = Kanna.HTML(html: myHTMLString, encoding: String.Encoding.utf8) else {
          //TODO: Not able to create Kanna HTML document. How to handle?
          DebugPrint.error("Not able to create Kanna HTML document")
          return
        }

        guard let cssSelector = self.cssField?.text else {
          DebugPrint.error("CSS field empty")
          return
        }

        var matchNum = 0
        for show in doc.css(cssSelector) {
          
          guard let imgSrc = show["src"] else {
            break
          }
          
          print("This is match #\(matchNum)")
          print(imgSrc)
          
          if let imgAlt = show["alt"] {
            print(imgAlt)
          }
          
          // Blogspot: Look for blogspot in URL, then remove /s320/ with /s3000/
          // Squaresapce: Look for squarespace in URL, then add ?format=3000w
          // Wordpress: Look for generator = Wordpress. Look for an x between 2 numbers, then remove '- number x number'
          // Wordpress.com: Look for wordpress.com mentionings, Remove ?w=number&h=number
          // Medium: Look for medium in URL. Look for /max/number, replace with /max/bigger number
          // Tumblr: No way...?
          
          matchNum = matchNum + 1
        }
        
        DebugPrint.log("Parsing Complete")
        
        
      } else {
        // TODO: Gotta handle other return status codes
        DebugPrint.error("response.statusCode = \(response.statusCode)")
      }
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
}
