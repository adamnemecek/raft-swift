//
//  RaftView.swift
//  swift-raft
//
//  Created by Frank the Tank on 7/11/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import UIKit
import Stevia
import FontAwesome_swift

class RaftView: UIView {
    let electionTimer = UILabel()
    let log = UITableView()
    let state = UITableView()
    let logTitle = UILabel()
    let role = UILabel()
    let input = UITextField()
    let heart = UIImageView()
    let disconnect = UIButton()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        log.register(LogEntryCell.self, forCellReuseIdentifier: "LogEntryCell")
        state.register(StateVariableCell.self, forCellReuseIdentifier: "StateVariableCell")
        
        sv(
            [role,
            heart,
            input,
            logTitle,
            log,
            electionTimer,
            state,
            disconnect]
        )
        
        disconnect.backgroundColor = .red
        disconnect.text("disconnect")
        disconnect.showsTouchWhenHighlighted = true
        
        input.placeholder = "Input"
        input.clearsOnBeginEditing = true
        
        logTitle.text = "Log"
        
        role.text = "Role"
        electionTimer.text = "50"
        heart.image = UIImage.fontAwesomeIcon(name: .heart, textColor: UIColor.red, size: CGSize(width: 80, height: 80))
        heart.contentMode = .scaleAspectFit
        layout(
            0,
            |role-5-electionTimer-5-heart| ~ 50,
            0,
            |input|,
            0,
            |logTitle|,
            0,
            |log|,
            0,
            |disconnect|,
            0,
            |state| ~ 300,
            0
        )
    }
}
