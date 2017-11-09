//
//  EmailResetViewController
//  TastryApp
//
//  Created by Howard Lee on 2017-09-29.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit

class EmailResetViewController: OverlayViewController {
  
  
  // MARK: - Public Instance Variable
  var emailAddress: String?
  
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var exitButton: ExitButton!
  
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
        AlertDialog.standardPresent(from: self, title: .genericNetworkError, message: .networkTryAgain)
        return
      }
      
      AlertDialog.present(from: self, title: "Reset Requested", message: "Instruction to reset the password for \(email) have been sent!")
    }
  }
  
  
  @IBAction func exitAction(_ sender: ExitButton) {
    dismiss(animated: true, completion: nil)
  }

  
  // MARK: - View Controller Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    exitButton.crossLayer.strokeColor = UIColor.black.withAlphaComponent(0.8).cgColor
    exitButton.pressedCrossLayer.strokeColor = UIColor.black.withAlphaComponent(0.8).cgColor
  }
  
  
  override func viewWillDisappear(_ animated: Bool) {
    view.endEditing(true)
  }
}
