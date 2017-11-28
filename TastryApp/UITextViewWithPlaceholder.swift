//
//  UITextViewWithPlaceholder.swift
//  Repnote
//
//  Created by John Neumann on 11/01/2017.
//  Copyright © 2017 Audioy. All rights reserved.
//

import UIKit

class UITextViewWithPlaceholder: UITextView {
  
  
  // MARK: - Private Instance Variables
  
  private var originalTextColour: UIColor = UIColor.black
  private var placeholderTextColour: UIColor = UIColor(red: 0, green: 0, blue: 0.098, alpha: 0.22)
  
  
  
  // MARK: - Public Instance Variables
  
  var placeholder: String? {
    didSet{
      if let placeholder = placeholder {
        text = placeholder
      }
    }
  }
  
  
  override internal var text: String? {
    didSet{
      textColor = originalTextColour
      if text == placeholder{
        textColor = placeholderTextColour
      }
    }
  }
  
  
  override internal var textColor: UIColor? {
    didSet{
      if let textColor = textColor, textColor != placeholderTextColour{
        originalTextColour = textColor
        if text == placeholder{
          self.textColor = placeholderTextColour
        }
      }
    }
  }
  
  
  
  // MARK: - Private Instance Functions
  
  @objc private func removePlaceholder(){
    if text == placeholder{
      text = ""
    }
  }
  
  
  @objc private func addPlaceholder(){
    if text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "" {
      text = placeholder
    }
  }
  
  
  private func removePadding() {
    // Remove the padding top and left of the text view
    self.textContainer.lineFragmentPadding = 0
    self.textContainerInset = UIEdgeInsets.zero
    self.contentInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
  }
  
  
  private func addPlaceholderObserver() {
    // Listen for text view did begin editing
    NotificationCenter.default.addObserver(self, selector: #selector(removePlaceholder), name: NSNotification.Name.UITextViewTextDidBeginEditing, object: nil)
    // Listen for text view did end editing
    NotificationCenter.default.addObserver(self, selector: #selector(addPlaceholder), name: NSNotification.Name.UITextViewTextDidEndEditing, object: nil)
  }
  
  
  
  // MARK: - Public Instance Functions
  
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    removePadding()
    addPlaceholderObserver()
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    removePadding()
    addPlaceholderObserver()
  }
  
  
  override func layoutSubviews() {
    super.layoutSubviews()
    setup()
  }

  
  func setup() {
    textContainerInset = UIEdgeInsets.zero
    textContainer.lineFragmentPadding = 0
  }
  
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

