//
//  MyClass.swift EXAMPLE
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-02.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import Parse

class MyClass: PFObject {
  @NSManaged var identifier: String?
  @NSManaged var image: PFFile?
}


// This is just example of PFObject Subclassing from Appcoda
extension MyClass {
  
  static func fetchImage(identifier: String,
                         completion: ((_ error: Error?, _ image: UIImage?) -> Void)?) {
    if let query = MyClass.query() {
    
      query.whereKey("identifier", equalTo: identifier)
      query.getFirstObjectInBackground { (object, error) in
        
        if let error = error {
          
          if let completion = completion {
            completion(error, nil)
          }
          
        } else if let object = object as? MyClass, let image = object.image {
          
          image.getDataInBackground { (data, error) in
            
            if let error = error { completion?(error, nil) }
            else if let data = data, let image = UIImage(data: data) { completion?(nil, image) }
          }
        }
      }
    }
  }
}

extension MyClass: PFSubclassing {
  static func parseClassName() -> String {
    return "MyClass"
  }
}
