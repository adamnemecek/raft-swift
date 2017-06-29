//
//  SocketManager.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/29/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

final class SocketManager {
    var udpUnicastSocket: GCDAsyncUdpSocket?
    var udpMulticastSendSocket: GCDAsyncUdpSocket?
    var udpMulticastReceiveSocket: GCDAsyncUdpSocket?
    
    let multicastIp = "225.1.2.3" // multicast address range 224.0.0.0 to 239.255.255.255
    
    var sendQueue = DispatchQueue.init(label: "send")
    var receiveQueue = DispatchQueue.init(label: "receive")
    var unicastQueue = DispatchQueue.init(label: "unicast")
    // var sharedRpcManager : rpcManager
    
    private init() {
        udpMulticastSendSocket = GCDAsyncUdpSocket(delegate: self as? GCDAsyncUdpSocketDelegate, delegateQueue: sendQueue)
        udpMulticastReceiveSocket = GCDAsyncUdpSocket(delegate: self as? GCDAsyncUdpSocketDelegate, delegateQueue: receiveQueue)
        setupMulticastSockets()
        
        udpUnicastSocket = GCDAsyncUdpSocket(delegate: self as? GCDAsyncUdpSocketDelegate, delegateQueue: unicastQueue)
        setupUnicastSocket()
        
        
    }
    
    static let shared = SocketManager()
    
    func setupMulticastSockets() {
        guard let sendSocket = udpMulticastSendSocket, let receiveSocket = udpMulticastReceiveSocket else {
            print("Couldn't setup multicast sockets")
            return
        }
        
        do {
            try sendSocket.bind(toPort: 0)
            try sendSocket.joinMulticastGroup(multicastIp)
            try sendSocket.enableBroadcast(true)
            try receiveSocket.bind(toPort: 2001)
            try receiveSocket.joinMulticastGroup(multicastIp)
            try receiveSocket.beginReceiving()
        } catch {
            print(error)
        }
    }
    
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
    
    func sendJsonMulticast(jsonToSend: Data) {
        guard let socket = udpMulticastSendSocket else {
            print("Stuff could not be initialized")
            return
        }
        
        socket.send(jsonToSend, toHost: multicastIp, port: 2001, withTimeout: -1, tag: 0)
    }
    
    // Receive multicast and unicast
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        var receivedJSON = JsonHelper.convertDataToJson(data)
        let jsonReader = JsonReader(receivedJSON)
        
        if (jsonReader.type == "redirect") {
            // Handle redirecting message to leader
            receiveClientMessage(message: jsonReader.message)
        } else if (jsonReader.type == "appendEntriesRequest") {
            // Handle append entries request
            handleAppendEntriesRequest(receivedJSON: receivedJSON)
            print("received mssg omg")
        } else if (jsonReader.type == "appendEntriesResponse") {
            // Handle success and failure
            // Need to check if nextIndex is still less, otherwise send another appendEntries thing
            handleAppendEntriesResponse(receivedJSON: receivedJSON)
        } else if (jsonReader.type == "requestVoteRequest") {
            handleRequestVoteRequest(receivedJSON: receivedJSON)
        } else if (jsonReader.type == "requestVoteResponse") {
            handleRequestVoteResponse(receivedJSON: receivedJSON)
        }
    }
}
