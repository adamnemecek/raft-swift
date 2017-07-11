//
//  LogEntryCell.swift
//  swift-raft
//
//  Created by Frank the Tank on 7/11/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import UIKit
import Stevia

class LogEntryCell: UITableViewCell {

    let committed = UIImageView()
    let message = UILabel()
    
    required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder)}
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        sv(
            [message.style(messageStyle),
            committed]
        )
        message.backgroundColor = .gray
        committed.width(80)
        committed.contentMode = .scaleAspectFit
        
        layout(
            0,
            |-message-10-committed-| ~ 80,
            0
        )
    }
    
    func messageStyle(l:UILabel) {
        l.font = .systemFont(ofSize: 24)
        l.textColor = .blue
    }
}
