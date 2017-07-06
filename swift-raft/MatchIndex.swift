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
    
    init(_ cluster: Cluster) {
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
}
