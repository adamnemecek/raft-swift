//
//  MatchIndex.swift
//  swift-raft
//
//  Created by Frank the Tank on 7/6/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation

class MatchIndex {
    var matchIndex: [String : Int]
    var clust: Cluster
    init(_ cluster: Cluster) {
        clust = cluster
        matchIndex = [String : Int]()
        for server in cluster.getPeers() {
            matchIndex[server] = 0
        }
    }
    
    func getMatchIndex(_ server: String) -> Int? {
        guard let index = matchIndex[server] else {
            print("Fail to get match index")
            return nil
        }
        
        return index
    }
    
    func setMatchIndex(server: String, index: Int) {
        matchIndex[server] = index
    }
    
    func getNextCommitIndex(currentCommitIndex: Int) -> Int {
        let nextCommitIndex = currentCommitIndex + 1
        var count = 0
        for (_, matchIdx) in matchIndex {
            if (matchIdx >= nextCommitIndex) {
                count = count + 1
            }
        }
        if (count > clust.majorityCount) {
            return nextCommitIndex
        } else {
            return currentCommitIndex
        }
    }
}
