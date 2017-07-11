//
//  RaftView.swift
//  swift-raft
//
//  Created by Frank the Tank on 7/11/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import UIKit
import Stevia

class RaftView: UIView {
    let electionTimer = UILabel()
    let log = UITableView()
    let state = UITableView()
    let logTitle = UILabel()
    let role = UILabel()
    let logTextView = UITextView()
    let input = UITextField()
    let heart = UIImageView()
    let disconnect = UIButton()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        log.register(LogEntryCell.self, forCellReuseIdentifier: "LogEntryCell")
        state.register(StateVariableCell.self, forCellReuseIdentifier: "StateVariableCell")
        
        sv(
            role,
            heart,
            input,
            logTitle,
            log,
            disconnect
        )
        
        layout(
            0,
            |-role-electionTimer-heart-|,
            5,
            |-logTitle-|,
            5,
            |-0-log-0-|,
            5,
            |-state-disconnect-|,
            0
        )
    }
}
