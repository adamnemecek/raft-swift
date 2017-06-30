//
//  RpcManager.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/29/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation
import SwiftyJSON

class RpcManager {
    var currentTerm: Int // server manager?
    var cluster: Cluster?
    var socket: Socket?
    var log: Log?
    var role = Role.Follower
    
    enum Role {
        case Follower
        case Candidate
        case Leader
    }
    
    private init() {
        cluster = Cluster()
        socket = Socket()
        log = Log()
        currentTerm = 1
    }
    
    static let shared = RpcManager()
    
    func receiveClientMessage(_ message: String) {
        guard let leaderIp = cluster?.leaderIp else {
            print("No leader IP")
            return
        }
        print("Received a client message")
        
        if (role == Role.Follower || role == Role.Candidate || leaderIp != cluster?.selfIp) {
            // Redirect request to leader
            if let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createRedirectMessageJson(message)) {
                socket?.sendJsonUnicast(jsonToSend: jsonToSend, targetHost: leaderIp)
            }
        } else if (role == Role.Leader) {
            // Add to log and send append entries RPC
            let jsonToStore = JsonHelper.createLogEntryJson(message: message, term: currentTerm, leaderIp: leaderIp)
            log?.addEntryToLog(jsonToStore)
            updateLogTextField()
            appendEntries()
            print("Called appendEntries")
        }
    }
    
    func appendEntries() {
        guard let peers = cluster?.getPeers(), let leaderIp = cluster?.leaderIp else {
            print("Couldn't get peers to send entries to")
        }
        for server in peers {
            
        }
    }
}
