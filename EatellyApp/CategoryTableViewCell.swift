//
//  CategoryTableViewCell
//  EatellyApp
//
//  Created by Howard Lee on 2017-09-07.
//  Copyright © 2017 Eatelly. All rights reserved.
//

import UIKit

class CategoryTableViewCell: UITableViewCell {
  
  // MARK: - IBOutlet
  @IBOutlet weak var triangleIndicatorView: UIView?
  @IBOutlet weak var titleLabel: UILabel?
  @IBOutlet weak var indicatorLeadingConstraint: NSLayoutConstraint?
  
  
  // MARK: - Public Instance Functions
  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    // Configure the view for the selected state
  }
  
}
