//
//  UIVideoEditorController.swift
//  TastoryApp
//
//  Created by Victor Tsang on 2018-03-19.
//  Copyright © 2018 Tastry. All rights reserved.
//

import UIKit

// this class was created so that ipad would display the apple's video trimmer in full screen on the ipad
class VideoEditorController: UIVideoEditorController {

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if UIDevice.current.userInterfaceIdiom == .pad {

      guard let popController = self.popoverPresentationController else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("PopoverPresentationController must exists when presenting Video Editor controller")
        }
        return
      }

      guard let container = popController.containerView else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("Container view is nil")
        }
        return
      }

      guard let presented = popController.presentedView else {
        AlertDialog.standardPresent(from: self, title: .genericInternalError, message: .inconsistencyFatal) { _ in
          CCLog.fatal("Presented view is nil")
        }
        return
      }

      view.superview?.layer.cornerRadius = 0
      container.backgroundColor = .black
      presented.bounds = UIScreen.main.bounds
      presented.setNeedsDisplay()
    }
  }
}
