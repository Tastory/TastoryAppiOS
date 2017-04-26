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
  @IBOutlet weak var titleTextField: UITextField?
  @IBOutlet weak var venueTextField: UITextField?
  @IBOutlet weak var linkTextField: UITextField?
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
    static let mapHeight: CGFloat = UIScreen.main.bounds.height/4
    static let momentHeight: CGFloat = UIScreen.main.bounds.height/3
    static let momentWidthDefault: CGFloat = Constants.momentHeight/16*9
    static let momentSizeDefault = CGSize(width: Constants.momentWidthDefault, height: Constants.momentHeight)
    static let momentCellReuseId = "momentCell"
    static let headerElementReuseId = "headerElement"
    static let footerElementReuseId = "footerElement"
  }
  
  
  // MARK: - Private Instance Constants
  fileprivate let sectionOneView = UIView()
  fileprivate let sectionTwoView = UIView()
  fileprivate let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Constants.mapHeight))

  
  // MARK: - Private Instance Variables
  fileprivate var placeholderLabel = UILabel()
  fileprivate var momentView: UICollectionView!
  fileprivate var momentCollectionLayout = MomentCollectionLayout()
  fileprivate let editingJournal: FoodieJournal = FoodieJournal.editingJournal!  // Let it crash if there is no editing Journal. Caller is responsible to setup
  
  
  // MARK: - Controller View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    momentCollectionLayout.scrollDirection = .horizontal
    momentCollectionLayout.minimumLineSpacing = 5
    momentCollectionLayout.minimumInteritemSpacing = 5
    momentCollectionLayout.headerReferenceSize = CGSize(width: 1, height: Constants.momentHeight)
    momentCollectionLayout.footerReferenceSize = Constants.momentSizeDefault
    momentCollectionLayout.itemSize = Constants.momentSizeDefault // This should be per item override by the delegate
    momentCollectionLayout.estimatedItemSize = momentCollectionLayout.itemSize
    momentCollectionLayout.maximumHeaderStretchWidth = Constants.momentWidthDefault
    //momentCollectionLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    
    momentView = UICollectionView(frame: CGRect(x: 0, y: 0,
                                                width: UIScreen.main.bounds.width,
                                                height: Constants.momentHeight),
                                  collectionViewLayout: momentCollectionLayout)
    
    momentView.register(MomentCollectionViewCell.self, forCellWithReuseIdentifier: Constants.momentCellReuseId)
    momentView.register(MomentHeaderReusableView.self,
                        forSupplementaryViewOfKind: UICollectionElementKindSectionHeader,
                        withReuseIdentifier: Constants.headerElementReuseId)
    momentView.register(MomentFooterReusableView.self,
                        forSupplementaryViewOfKind: UICollectionElementKindSectionFooter,
                        withReuseIdentifier: Constants.footerElementReuseId)
    momentView.delegate = self
    momentView.dataSource = self
    momentView.backgroundColor = UIColor.white
    
    sectionOneView.addSubview(mapView)
    sectionTwoView.addSubview(momentView)
    
    titleTextField?.delegate = self
    venueTextField?.delegate = self
    linkTextField?.delegate = self
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

  
  // MARK: - Table View Data Source
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
  
  
  // MARK: - Scroll View Delegate
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let currentOffset = scrollView.contentOffset.y
    let height = ceil(Constants.mapHeight - currentOffset)
    
    if height == 0 {
      DebugPrint.fatal("Height cannot be value of 0")
    }
    
    // Need to take the ceiling as a 0 height with cause a crash
    mapView.frame = CGRect(x: 0, y: currentOffset, width: self.view.bounds.width, height: height)
  }
  
  
  // MARK: - Helper Functions
  func keyboardDismiss() {
    self.view.endEditing(true)
  }
  
  func previousUnwind() {
    // Careful here, if we didn't arrive at this view from Camera View, we will not be able to exit (naturally)
    self.performSegue(withIdentifier: "unwindToCamera", sender: self)
    
    // TODO: Should look through all VC in the stack to determine whichone to return to
  }
}


// MARK: - Collection View DataSource
extension JournalEntryViewController: UICollectionViewDataSource {
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    
    if let moments = editingJournal.moments {
      return moments.count
    } else {
      return 10
    }
  }
  
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Constants.momentCellReuseId, for: indexPath)
    cell.backgroundColor = UIColor.cyan
    return cell
  }
  
  
  func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    
    var reusableView: UICollectionReusableView!
    
    switch kind {
    case UICollectionElementKindSectionHeader:
      reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: Constants.headerElementReuseId, for: indexPath)
      //reusableView.backgroundColor = UIColor.green
    case UICollectionElementKindSectionFooter:
      reusableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: Constants.footerElementReuseId, for: indexPath)
      //reusableView.backgroundColor = UIColor.blue
    default:
      DebugPrint.fatal("Unrecognized Kind '\(kind)' for Supplementary Element")
    }
    return reusableView
  }
}


// MARK: - Collection View Delegate
extension JournalEntryViewController: UICollectionViewDelegate {

}


// MARK: - Tags TextView Delegate
extension JournalEntryViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    placeholderLabel.isHidden = !textView.text.isEmpty
  }
}


// MARK: - Text Fields' Delegate
extension JournalEntryViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}
