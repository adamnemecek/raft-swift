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
    
    let commitIndexLabel = UILabel()
    let votedForLabel = UILabel()
    let currentTermLabel = UILabel()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        log.register(LogEntryCell.self, forCellReuseIdentifier: "LogEntryCell")
        state.register(StateVariableCell.self, forCellReuseIdentifier: "StateVariableCell")
        
        sv(
            [
            role,
            heart,
            input,
            logTitle,
            log,
            electionTimer,
            state,
            disconnect,
            commitIndexLabel,
            votedForLabel,
            currentTermLabel
            ]
        )
        
        equalSizes(role, heart, electionTimer)
        equalSizes(commitIndexLabel, votedForLabel, currentTermLabel)
        disconnect.backgroundColor = .red
        disconnect.text("disconnect")
        disconnect.showsTouchWhenHighlighted = true
        
        input.placeholder = "Input"
        input.borderStyle = .roundedRect
        input.layer.borderColor = UIColor.darkGray.cgColor
        input.clearsOnBeginEditing = true
        input.textAlignment = .center
        input.font = input.font?.withSize(30)
        
        logTitle.text = "Log Entries"
        logTitle.textAlignment = .center
        logTitle.font  = logTitle.font.withSize(30)
        
        role.font = role.font.withSize(30)
        role.text = "Role"
        role.textAlignment = .center
        
        electionTimer.textAlignment = .center
        electionTimer.font = role.font.withSize(30)
        electionTimer.text = "5"
        
        heart.image = UIImage.fontAwesomeIcon(name: .heart, textColor: UIColor.gray, size: CGSize(width: 50, height: 50))
        heart.contentMode = .scaleAspectFit
        
        
        commitIndexLabel.text = "Commit Index: 20"
        commitIndexLabel.font = commitIndexLabel.font.withSize(20)
        commitIndexLabel.textAlignment = .center
        
        votedForLabel.text = "Voted For: 192.168.10.57"
        votedForLabel.font = votedForLabel.font.withSize(20)
        votedForLabel.textAlignment = .center
        
        currentTermLabel.text = "Current Term: 25"
        currentTermLabel.font = currentTermLabel.font.withSize(20)
        currentTermLabel.textAlignment = .center
        
        layout(
            0,
            |role-5-electionTimer-5-heart| ~ 100,
            0,
            |currentTermLabel-votedForLabel-commitIndexLabel| ~ 100,
            0,
            |input| ~ 100,
            0,
            |logTitle| ,
            0,
            |log|,
            0,
            |disconnect| ~ 75,
            0
        )
    }
}
