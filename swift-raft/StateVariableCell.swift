//
//  StateVariableCell.swift
//  swift-raft
//
//  Created by Frank the Tank on 7/11/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import UIKit
import Stevia

class StateVariableCell: UITableViewCell {

    let stateVariableName = UILabel()
    let stateVariableValue = UILabel()
    
    required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder)}
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        sv(
            stateVariableName.style(nameStyle),
            stateVariableValue.style(nameStyle)
        )
        
        layout(
            |-stateVariableName-stateVariableValue-|
        )
    }
    
    func nameStyle(l:UILabel) {
        l.font = .systemFont(ofSize: 24)
        l.textColor = .blue
    }

}
