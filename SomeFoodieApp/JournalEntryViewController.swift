//
//  JournalEntryViewController.swift
//  SomeFoodieApp
//
//  Created by Howard Lee on 2017-04-20.
//  Copyright © 2017 Howard's Creative Innovations. All rights reserved.
//

import UIKit
import MapKit

class JournalEntryViewController: UITableViewController {

  // MARK: - IBOutlets
  @IBOutlet weak var tagsTextView: UITextView? {
    didSet {
      placeholderLabel = UILabel(frame: CGRect(x: 5, y: 7, width: 49, height: 19))
      placeholderLabel.text = "Tags"
      placeholderLabel.textColor = UIColor(red: 0xC8/0xFF, green: 0xC8/0xFF, blue: 0xC8/0xFF, alpha: 1.0)
      placeholderLabel.font = UIFont.systemFont(ofSize: 14)
      placeholderLabel.isHidden = !tagsTextView!.text.isEmpty
      tagsTextView?.addSubview(placeholderLabel)
    }
  }

  
  // MARK: - Private Class Constants
  fileprivate struct Constants {
    static let mapHeight: CGFloat = UIScreen.main.bounds.height/5
    static let momentHeight: CGFloat = UIScreen.main.bounds.height/3
  }
  
  
  // MARK: - Private Instance Constants
  fileprivate let sectionOneView = UIView()
  fileprivate let sectionTwoView = UIView()
  fileprivate let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Constants.mapHeight))
  fileprivate let momentView = UICollectionView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Constants.momentHeight), collectionViewLayout: UICollectionViewFlowLayout())
  
  
  // MARK: - Private Instance Variables
  fileprivate var placeholderLabel = UILabel()
  
  
  // MARK: - Controller View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    sectionOneView.addSubview(mapView)
    sectionTwoView.addSubview(momentView)
    
    tagsTextView?.delegate = self
    
    let keyboardDismissRecognizer = UITapGestureRecognizer(target: self, action: #selector(keyboardDismiss))
    keyboardDismissRecognizer.numberOfTapsRequired = 1
    keyboardDismissRecognizer.numberOfTouchesRequired = 1
    tableView.addGestureRecognizer(keyboardDismissRecognizer)
    
    let previousSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(previousUnwind))
    previousSwipeRecognizer.direction = .right
    previousSwipeRecognizer.numberOfTouchesRequired = 1
    tableView.addGestureRecognizer(previousSwipeRecognizer)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Table view data source
  
  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    switch section {
    case 0:
      return sectionOneView
    case 1:
      return sectionTwoView
    default:
      return nil
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    switch section {
    case 0:
      return Constants.mapHeight
    case 1:
      return Constants.momentHeight
    default:
      return 0
    }
  }
  
  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 1
  }
  
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let currentOffset = scrollView.contentOffset.y
    let height = ceil(Constants.mapHeight - currentOffset)
    
    if height == 0 {
      DebugPrint.fatal("Height cannot be value of 0")
    }
    
    // Need to take the ceiling as a 0 height with cause a crash
    mapView.frame = CGRect(x: 0, y: currentOffset, width: self.view.bounds.width, height: height)
  }
  
  func keyboardDismiss() {
    self.view.endEditing(true)
  }
  
  func previousUnwind() {
    // Careful here, if we didn't arrive at this view from Camera View, we will not be able to exit (naturally)
    self.performSegue(withIdentifier: "unwindToCamera", sender: self)
    
    // TODO: Should look through all VC in the stack to determine whichone to return to
  }
}

extension JournalEntryViewController: UITextViewDelegate {
  
  func textViewDidChange(_ textView: UITextView) {
    placeholderLabel.isHidden = !textView.text.isEmpty
  }
}


extension JournalEntryViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}
