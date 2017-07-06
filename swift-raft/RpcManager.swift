//
//  RpcManager.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/29/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation
import SwiftyJSON
import CocoaAsyncSocket

class RpcManager {
    // MARK: RPC Manager Variables
    
    var currentTerm: Int
    var cluster: Cluster
    var nextIndex: NextIndex
    var log: Log
    var role = Role.Follower
    
    enum Role {
        case Follower
        case Candidate
        case Leader
    }
    
    // MARK: Socket Variables
    
    var udpUnicastSocket: GCDAsyncUdpSocket?
    
    // MARK: Initialize RpcManager Singleton
    
    private init() {
        // Initialize RpcManager variables
        cluster = Cluster()
        nextIndex = NextIndex(cluster)
        log = Log()
        currentTerm = 1
        
        // Initialize Socket variables
        let unicastQueue = DispatchQueue.init(label: "unicast")
        udpUnicastSocket = GCDAsyncUdpSocket(delegate: self as? GCDAsyncUdpSocketDelegate, delegateQueue: unicastQueue)
        setupUnicastSocket()
    }
    
    static let shared = RpcManager()
    
    // MARK: Socket Methods
    
    func setupUnicastSocket() {
        guard let socket = udpUnicastSocket else {
            print("Couldn't setup sockets")
            return
        }
        
        do {
            try socket.bind(toPort: 20011)
            try socket.beginReceiving()
        } catch {
            print(error)
        }
    }
    
    func sendJsonUnicast(jsonToSend: Data, targetHost: String) {
        guard let socket = udpUnicastSocket else {
            print("Socket or leaderIp could not be initialized")
            return
        }
        
        socket.send(jsonToSend, toHost: targetHost, port: 20011, withTimeout: -1, tag: 0)
    }
    
    // Receive UDP packets
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let receivedJSON = JsonHelper.convertDataToJson(data)
        let jsonReader = JsonReader(receivedJSON)
        
        if (jsonReader.type == "redirect") {
            // Handle redirecting message to leader
            guard let message = jsonReader.message else {
                print("Couldn't get message for redirect")
                return
            }
            receiveClientMessage(message)
        } else if (jsonReader.type == "appendEntriesRequest") {
            // Handle append entries request
//            handleAppendEntriesRequest(receivedJSON: receivedJSON)
        } else if (jsonReader.type == "appendEntriesResponse") {
            // Handle success and failure
            // Need to check if nextIndex is still less, otherwise send another appendEntries thing
            //            handleAppendEntriesResponse(receivedJSON: receivedJSON)
        } else if (jsonReader.type == "requestVoteRequest") {
            //            handleRequestVoteRequest(receivedJSON: receivedJSON)
        } else if (jsonReader.type == "requestVoteResponse") {
            //            handleRequestVoteResponse(receivedJSON: receivedJSON)
        }
    }
    
    // MARK: Handle RPC Methods
    
    func receiveClientMessage(_ message: String) {
        let leaderIp = cluster.leaderIp
        
        if (role == Role.Leader) {
            // Add to log and send append entries RPC
            let jsonToStore = JsonHelper.createLogEntryJson(message: message, term: currentTerm, leaderIp: leaderIp)
            log.addEntryToLog(jsonToStore)
            appendEntries()
        } else {
            // Redirect request to leader
            if let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createRedirectMessageJson(message)) {
                sendJsonUnicast(jsonToSend: jsonToSend, targetHost: leaderIp)
            }
        }
    }
    
    func appendEntries() {
        for server in cluster.getPeers() {
            guard let nextIdx = nextIndex.getNextIndex(server) else {
                return
            }
            
            let prevLogIdx = nextIdx - 1
            
            guard let prevLogTerm = log.getLogTerm(prevLogIdx), let message = log.getLogMessage(nextIdx) else {
                print("Could not get previous log term and message")
                return
            }
            
            guard let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesRequestJson(leaderIp: cluster.leaderIp, message: message, senderCurrentTerm: currentTerm, prevLogIndex: prevLogIdx, prevLogTerm: prevLogTerm, leaderCommitIndex: log.commitIndex)) else {
                print("Could not create json to send")
                return
            }
            
            sendJsonUnicast(jsonToSend: jsonToSend, targetHost: server)
        }
    }
}
