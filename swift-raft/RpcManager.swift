//
//  RpcManager.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/29/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation

class RpcManager {
    var commitIndex: Int?
    
    enum Role {
        case Follower
        case Candidate
        case Leader
    }
    
    private init() {
        
    }
    
    static let shared = RpcManager()
    
    func receiveClientMessage() {
        guard let leaderIp = leaderIp else {
            print("No leader IP")
            return
        }
        print("inside receiveclientmessage")
        if (role == FOLLOWER || role == CANDIDATE || leaderIp != getIFAddresses()[1]) {
            // Redirect request to leader
            let jsonToSend : JSON = [
                "type" : "redirect",
                "address" : leaderIp,
                "message" : message,
                "from" : getIFAddresses()[1],
                "currentTerm" : currentTerm
            ]
            
            guard let jsonData = jsonToSend.rawString()?.data(using: String.Encoding.utf8) else {
                print("Couldn't create JSON or get leader IP")
                return
            }
            print("TEARDRIOS")
            print(leaderIp)
            
            sendJsonUnicast(jsonToSend: jsonData, targetHost: leaderIp)
        } else if (role == LEADER) {
            // Add to log and send append entries RPC
            let jsonToStore : JSON = [
                "type" : "entry",
                "term" : currentTerm,
                "message" : message,
                "leaderIp" : leaderIp,
                ]
            log.append(jsonToStore)
            updateLogTextField()
            appendEntries()
            print("append entries called")
        }
    }
}
