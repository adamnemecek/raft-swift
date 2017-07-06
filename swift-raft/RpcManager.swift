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
    var votedFor: String?
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
        votedFor = nil
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
        let receivedJson = JsonHelper.convertDataToJson(data)
        let jsonReader = JsonReader(receivedJson)
        
        if (jsonReader.type == "redirect") {
            // Handle redirecting message to leader
            guard let message = jsonReader.message else {
                print("Couldn't get message for redirect")
                return
            }
            receiveClientMessage(message)
        } else if (jsonReader.type == "appendEntriesRequest") {
            // Handle append entries request
            handleAppendEntriesRequest(readJson: jsonReader)
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
    
    func stepDown(term: Int) {
        role = Role.Follower
        currentTerm = term
        votedFor = nil
    }
    
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
    
    func handleAppendEntriesRequest(readJson: JsonReader) {
        guard let senderTerm = readJson.senderCurrentTerm, let selfIp = cluster.selfIp else {
            print("Couldn't get sender term or self ip")
            return
        }
        
        if (currentTerm < senderTerm) {
            stepDown(term: senderTerm)
        }
        
        guard let rpcSender = readJson.sender else {
            print("No sender")
            return
        }
        
        if (currentTerm > senderTerm) {
            guard let response = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesResponseJson(success: false, senderCurrentTerm: currentTerm, sender: selfIp)) else {
                print("Fail to create response")
                return
            }
            sendJsonUnicast(jsonToSend: response, targetHost: rpcSender)
        } else {
            cluster.updateLeaderIp(rpcSender)
            role = Role.Follower
            guard let prevLogIdx = readJson.prevLogIndex, let prevLogTerm = readJson.prevLogTerm else {
                print("Error with previous log index or term")
                return
            }
            var success = false
            if (prevLogIdx == 0 || prevLogIdx <= log.getLastLogIndex()) {
                guard let term = log.getLogTerm(prevLogIdx) else {
                    print("Fail to get term")
                    return
                }
                if (prevLogTerm == term) {
                    success = true
                }
            }
            var idx = 0
            
            if (success) {
                idx = prevLogIdx + 1
                guard let term = log.getLogTerm(idx) else {
                    print("Fail to get term")
                    return
                }
                if (term != senderTerm) {
                    guard let message = readJson.message else {
                        print("Fail to get message")
                        return
                    }
                    log.sliceAndAppend(idx: idx, entry: JsonHelper.createLogEntryJson(message: message, term: currentTerm, leaderIp: cluster.leaderIp))
                    
                    guard let senderCommitIndex = readJson.leaderCommitIndex else {
                        print("Fail to get leader commit index")
                        return
                    }
                    
                    if (senderCommitIndex > log.commitIndex) {
                        log.updateCommitIndex(min(senderCommitIndex, idx))
                    }
                }
            }
            
            guard let response = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesResponseJson(success: success, senderCurrentTerm: currentTerm, sender: selfIp)) else {
                print("Fail to create response")
                return
            }
            
            sendJsonUnicast(jsonToSend: response, targetHost: cluster.leaderIp)
        }
    }
    
    
}
