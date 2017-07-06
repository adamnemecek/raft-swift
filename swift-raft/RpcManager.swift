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
    
    // MARK: Socket Variables
    var udpUnicastSocket: GCDAsyncUdpSocket?
    
    // MARK: Initialize RpcManager Singleton
    
    private init() {
        // Initialize RpcManager variables
        cluster = Cluster()
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
        guard let leaderIp = cluster?.leaderIp else {
            print("No leader IP")
            return
        }
        
        if (role == Role.Leader) {
            // Add to log and send append entries RPC
            let jsonToStore = JsonHelper.createLogEntryJson(message: message, term: currentTerm, leaderIp: leaderIp)
            log?.addEntryToLog(jsonToStore)
            updateLogTextField()
            appendEntries()
        } else {
            // Redirect request to leader
            if let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createRedirectMessageJson(message)) {
                socket?.sendJsonUnicast(jsonToSend: jsonToSend, targetHost: leaderIp)
            }
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
