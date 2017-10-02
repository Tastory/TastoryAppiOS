//
//  CategoryTableViewCell
//  TastryApp
//
//  Created by Howard Lee on 2017-09-07.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit


protocol CategoryTableViewCellDelegate {
  func expandCollpase(for cell: CategoryTableViewCell, to state: CategoryTableViewCell.ExpandCollapseState)
}


class CategoryTableViewCell: UITableViewCell {
  
  // MARK: - Enumeration
  enum ExpandCollapseState {
    case expand
    case collapse
  }
  
  
  // MARK: - IBOutlet
  @IBOutlet weak var categoryIconView: UIView?
  @IBOutlet weak var titleLabel: UILabel?
  @IBOutlet weak var iconLeadingConstraint: NSLayoutConstraint?
  @IBOutlet weak var expandButton: ExpandButton!
  
  @IBAction func expandButtonAction(_ sender: ExpandButton) {
    
    switch state {
    case .expand:
      state = .collapse
      expandButton.rotateToCollapse()
    case .collapse:
      state = .expand
      expandButton.rotateToExpand()
    }
    
    delegate?.expandCollpase(for: self, to: state)
  }
  
  
  // MARK: - Public Instance Variable
  var delegate: CategoryTableViewCellDelegate?
  var categoryItem: FoodieCategory?
  
  // MARK: - Private Instance Variables
  fileprivate var state = ExpandCollapseState.collapse
  
  
  // MARK: - Public Instance Functions
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
    
    categoryIconView?.layer.cornerRadius = 2.0
    categoryIconView?.layer.borderWidth = 2.0
    categoryIconView?.layer.borderColor = UIColor.orange.cgColor
    categoryIconView?.layer.backgroundColor = UIColor.clear.cgColor
  }
}
