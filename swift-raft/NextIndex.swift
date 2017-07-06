//
//  NextIndex.swift
//  swift-raft
//
//  Created by Frank the Tank on 7/5/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation

class NextIndex {
    var nextIndex: [String : Int]
    
    init(_ cluster: Cluster) {
        nextIndex = [String : Int]()
        for server in cluster.getPeers() {
            nextIndex[server] = 1
        }
    }
    
    func getNextIndex(_ server: String) -> Int? {
        guard let index = nextIndex[server] else {
            print("Problem getting next index")
            return nil
        }
        
        return index
    }
}
