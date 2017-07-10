//
//  VoteGranted.swift
//  swift-raft
//
//  Created by Frank the Tank on 7/10/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation

class VoteGranted {
    var voteGranted: [String : Bool]
    
    init(_ cluster: Cluster) {
        voteGranted = [String : Bool]()
        for server in cluster.getPeers() {
            voteGranted[server] = false
        }
    }
    
    func grantVote(server: String) {
        voteGranted[server] = true
    }
    
    func getVoteCount() -> Int {
        var voteCount = 0
        for (_, granted) in voteGranted {
            if (granted) {
                voteCount = voteCount + 1
            }
        }
        return voteCount
    }
}
