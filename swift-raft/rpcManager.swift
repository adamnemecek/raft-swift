//
//  rpcManager.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/29/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation

class rpcManager {
    private init() {
    
    }
    
    static let shared = rpcManager()
    
    enum Role {
        case Follower
        case Candidate
        case Leader
    }
    
    
}
