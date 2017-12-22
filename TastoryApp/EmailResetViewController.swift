//
//  EmailResetViewController
//  TastoryApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Tastory. All rights reserved.
//

import UIKit

class EmailResetViewController: OverlayViewController {
  
  
  // MARK: - Public Instance Variable
  var emailAddress: String?
  
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var emailField: UITextField! {
    didSet {
      emailField.text = emailAddress
    }
  }
  
  
  
  // MARK: - IBAction
  @IBAction func resetAction(_ sender: UIButton) {
    
    guard let email = emailField.text, FoodieUser.checkValidFor(email: email) else {
      CCLog.info("User entered invalid E-mail address for Reset")
      AlertDialog.present(from: self, title: "Invalid E-mail", message: "Invalid E-mail address entered for reset. Please correct and try again")
      return
    }
    
    FoodieUser.resetPassword(with: email) { error in
      if let error = error {
        CCLog.warning("Reset request for \(email) failed - \(error.localizedDescription)")
        AlertDialog.present(from: self, title: "Reset Error", message: error.localizedDescription)
        return
      }
      
      AlertDialog.present(from: self, title: "Reset Requested", message: "Instruction to reset the password for \(email) have been sent!")
    }
  }
  
  
  @IBAction func exitAction(_ sender: UIButton) {
    popDismiss(animated: true)
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
}
