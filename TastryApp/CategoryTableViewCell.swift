//
//  CategoryTableViewCell
//  TastryApp
//
//  Created by Howard Lee on 2017-09-07.
//  Copyright © 2017 Tastry. All rights reserved.
//

import UIKit


protocol CategoryTableViewCellDelegate: class {
  func expandCollpase(for cell: CategoryTableViewCell, to state: CategoryTableViewCell.ExpandCollapseState)
}


class CategoryTableViewCell: UITableViewCell {
  
  // MARK: - Enumeration
  enum ExpandCollapseState {
    case expand
    case collapse
  }
  
  
  // MARK: - Public Instance Variable
  weak var delegate: CategoryTableViewCellDelegate?
  var categoryItem: FoodieCategory?
  
  
  // MARK: - Private Instance Variables
  private var state = ExpandCollapseState.collapse
  
  
  // MARK: - IBOutlet
  @IBOutlet var titleLabel: UILabel!
  @IBOutlet var expandButton: UIButton!
  
  
  // MARK: - IBAction
  @IBAction func expandButtonAction(_ sender: UIButton) {
    switch state {
    case .expand:
      setAndAnimate(to: .collapse)
    case .collapse:
      setAndAnimate(to: .expand)
    }
    delegate?.expandCollpase(for: self, to: state)
  }
  
  
  // MARK: - Public Instance Function
  func setAndAnimate(to state: ExpandCollapseState) {
    switch state {
    case .collapse:
      self.state = .collapse
      UIView.animate(withDuration: 0.2, animations: {
        self.expandButton.transform = CGAffineTransform.identity
      })
      
    case .expand:
      self.state = .expand
      UIView.animate(withDuration: 0.2, animations: {
        self.expandButton.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
      })
    }
  }
}
