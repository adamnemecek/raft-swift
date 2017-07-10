//
//  ViewController.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/28/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import UIKit
import SwiftyJSON
import CocoaAsyncSocket

class ViewController: UIViewController, GCDAsyncUdpSocketDelegate {
    // MARK: RPC Manager Variables
    
    var currentTerm = 1
    var cluster = Cluster()
    var nextIndex: NextIndex?
    var matchIndex: MatchIndex?
    var voteGranted: VoteGranted?
    var log = Log()
    var votedFor: String?
    var role = Role.Follower
    var rpcDue = [String : Timer]()
    var electionTimer = Timer()
    enum Role {
        case Follower
        case Candidate
        case Leader
    }
    
    // MARK: Socket Variables
    
    var udpUnicastSocket: GCDAsyncUdpSocket?
    
    // MARK: Storyboard Variables
    
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var inputTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize RpcManager variables
        nextIndex = NextIndex(cluster)
        matchIndex = MatchIndex(cluster)
        voteGranted = VoteGranted(cluster)
        votedFor = nil
        startElectionTimer()
        // Initialize Socket variables
        let unicastQueue = DispatchQueue.init(label: "unicast")
        udpUnicastSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: unicastQueue)
        setupUnicastSocket()
        if (cluster.leaderIp == cluster.selfIp) {
            becomeLeader()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
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
            handleAppendEntriesResponse(readJson: jsonReader)
        } else if (jsonReader.type == "requestVoteRequest") {
            handleRequestVoteRequest(readJson: jsonReader)
        } else if (jsonReader.type == "requestVoteResponse") {
            //            handleRequestVoteResponse(receivedJSON: receivedJSON)
        }
    }
    
    // MARK: Update UI Methods
    
    @IBAction func pressButton(_ sender: Any) {
        print("Is Valid: " + electionTimer.isValid.description)
        print("FireDate: " + electionTimer.fireDate.description)
        print("Date: " + Date().description)
        print("LeaderIP: " + cluster.leaderIp)
        print("CurrentTerm: " + currentTerm.description )
    }
    @IBAction func editInputField(_ sender: Any) {
        guard let msg = inputTextField.text else {
            print("No message")
            return
        }
        receiveClientMessage(msg)
    }
    
    func updateRoleLabel() {
        DispatchQueue.main.async {
            if (self.isFollower()) {
                self.roleLabel.text = "Follower"
            } else if (self.isCandidate()) {
                self.roleLabel.text = "Candidate"
            } else {
                self.roleLabel.text = "Leader"
            }
        }
    }
    
    func updateLogTextField() {
        DispatchQueue.main.async {
            guard let logString = self.log.getLogEntriesString() else {
                print("Failed to get log entries as a string")
                return
            }
            self.logTextView.text = logString
        }
    }
    
    
    // MARK: Handle RPC Methods
    
    func resetTermVariables() {
        nextIndex = nil
        nextIndex = NextIndex(cluster)
        matchIndex = nil
        matchIndex = MatchIndex(cluster)
        voteGranted = nil
        voteGranted = VoteGranted(cluster)
    }
    
    func becomeFollower() {
        stopHeartbeatTimers()
        role = Role.Follower
        updateRoleLabel()
    }
    
    func becomeCandidate() {
        role = Role.Candidate
        updateRoleLabel()
    }
    
    func becomeLeader() {
        role = Role.Leader
        guard let selfIp = cluster.selfIp else {
            print("Failed to get selfIp")
            return
        }
        cluster.leaderIp = selfIp
        updateRoleLabel()
        for peer in cluster.getPeers() {
            startHeartbeatTimer(peer: peer)
        }
    }
    
    func isFollower() -> Bool {
        return role == Role.Follower
    }
    
    func isCandidate() -> Bool {
        return role == Role.Candidate
    }
    
    func isLeader() -> Bool {
        return role == Role.Leader
    }
    
    func stepDown(term: Int) {
        becomeFollower()
        currentTerm = term
        votedFor = nil
        resetElectionTimer()
    }
    
    func receiveClientMessage(_ message: String) {
        let leaderIp = cluster.leaderIp
        
        if (isLeader()) {
            // Add to log and send append entries RPC
            let jsonToStore = JsonHelper.createLogEntryJson(message: message, term: currentTerm, leaderIp: leaderIp)
            log.addEntryToLog(jsonToStore)
            updateLogTextField()
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
            guard let nextIdx = nextIndex?.getNextIndex(server), let selfIp = cluster.selfIp else {
                print("No self ip")
                return
            }
            
            let prevLogIdx = nextIdx - 1
            
            guard let prevLogTerm = log.getLogTerm(prevLogIdx), let message = log.getLogMessage(nextIdx) else {
                print("Could not get previous log term and message")
                return
            }
            
            guard let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesRequestJson(leaderIp: cluster.leaderIp, message: message, senderCurrentTerm: currentTerm, prevLogIndex: prevLogIdx, prevLogTerm: prevLogTerm, leaderCommitIndex: log.commitIndex, sender: selfIp)) else {
                print("Could not create json to send")
                return
            }
            resetHeartbeatTimer(peer: server)
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
            guard let response = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesResponseJson(success: false, senderCurrentTerm: currentTerm, sender: selfIp, matchIndex: 0)) else {
                print("Fail to create response")
                return
            }
            sendJsonUnicast(jsonToSend: response, targetHost: rpcSender)
        } else {
            cluster.updateLeaderIp(rpcSender)
            becomeFollower()
            resetElectionTimer()
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
                    updateLogTextField()
                    
                    guard let senderCommitIndex = readJson.leaderCommitIndex else {
                        print("Fail to get leader commit index")
                        return
                    }
                    
                    if (senderCommitIndex > log.commitIndex) {
                        log.updateCommitIndex(min(senderCommitIndex, idx))
                    }
                }
            }
            
            guard let response = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesResponseJson(success: success, senderCurrentTerm: currentTerm, sender: selfIp, matchIndex: idx)) else {
                print("Fail to create response")
                return
            }
            
            sendJsonUnicast(jsonToSend: response, targetHost: cluster.leaderIp)
        }
    }
    
    func sendAppendEntriesRequest(_ nextIdx: Int, _ sender: String) {
        let prevLogIdx = nextIdx - 1
        var prevLogTerm = 0
        if (prevLogIdx >= 0) {
            guard let term = log.getLogTerm(prevLogIdx) else {
                print("Couldn't get term")
                return
            }
            prevLogTerm = term
        }
        guard let sendMessage = log.getLogMessage(nextIdx), let selfIp = cluster.selfIp else {
            print("Failed to get message")
            return
        }
        guard let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesRequestJson(leaderIp: cluster.leaderIp, message: sendMessage, senderCurrentTerm: currentTerm, prevLogIndex: prevLogIdx, prevLogTerm: prevLogTerm, leaderCommitIndex: log.commitIndex, sender: selfIp)) else {
            print("Failed to create json data")
            return
        }
        
        resetHeartbeatTimer(peer: sender)
        sendJsonUnicast(jsonToSend: jsonToSend, targetHost: sender)
    }
    
    func handleAppendEntriesResponse(readJson: JsonReader) {
        guard let senderTerm = readJson.senderCurrentTerm, let success = readJson.success, let index = readJson.matchIndex, let sender = readJson.sender else {
            print("Failed to initialize proper variables")
            return
        }
        let nextIdx = index + 1
        if (currentTerm < senderTerm) {
            stepDown(term: senderTerm)
        } else if (isLeader() && currentTerm == senderTerm) {
            if (success) {
                matchIndex?.setMatchIndex(server: sender, index: index)
                nextIndex?.setNextIndex(server: sender, index: nextIdx)
                
                if (log.getLastLogIndex() >= nextIdx) {
                    sendAppendEntriesRequest(nextIdx, sender)
                }
            } else {
                guard let currentNextIndex = nextIndex?.getNextIndex(sender) else {
                    print("Failed to get next index")
                    return
                }
                let nextIdx = max(1, currentNextIndex - 1)
                nextIndex?.setNextIndex(server: sender, index: nextIdx)
                
                if (log.getLastLogIndex() >= nextIdx) {
                    sendAppendEntriesRequest(nextIdx, sender)
                }
            }
        }
    }

    
    func startHeartbeatTimer(peer: String) {
        let userInfo = JsonHelper.createUserInfo(peer: peer)
        guard let nextIdx = nextIndex?.getNextIndex(peer) else {
            print("Failed to get next index for peer")
            return
        }
        let heartbeatEntry = JsonHelper.createLogEntryJson(message: "Heartbeat: " + nextIdx.description, term: currentTerm, leaderIp: cluster.leaderIp)
        
        log.addEntryToLog(heartbeatEntry)
        updateLogTextField()
        sendAppendEntriesRequest(nextIdx, peer)
        rpcDue[peer] = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(sendHeartbeat(timer:)), userInfo: userInfo, repeats: true)
    }
    
    func sendHeartbeat(timer : Timer) {
        guard let peer = JsonReader((timer.userInfo as? JSON)!).peer, let nextIdx = nextIndex?.getNextIndex(peer) else {
            print("Failed to get peer from timer or next index")
            return
        }
        let heartbeatEntry = JsonHelper.createLogEntryJson(message: "Heartbeat: " + nextIdx.description, term: currentTerm, leaderIp: cluster.leaderIp)
        
        log.addEntryToLog(heartbeatEntry)
        updateLogTextField()
        sendAppendEntriesRequest(nextIdx, peer)
    }
    
    func resetHeartbeatTimer(peer: String) {
        let userInfo = JsonHelper.createUserInfo(peer: peer)
        rpcDue[peer]?.invalidate()
        rpcDue[peer] = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(sendHeartbeat(timer:)), userInfo: userInfo, repeats: true)
        print(rpcDue[peer]?.isValid)
    }
    
    func stopHeartbeatTimers() {
        for server in cluster.getPeers() {
            rpcDue[server]?.invalidate()
        }
    }
    
    func startElectionTimer() {
        electionTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.electionTimeout), userInfo: nil, repeats: true)
    }
    
    func resetElectionTimer() {
        DispatchQueue.main.async {
            self.electionTimer.invalidate()
            self.startElectionTimer()
        }
//        let comparison = electionTimer.fireDate.compare(Date())
//        guard comparison != .orderedAscending else {
//            print("Date is all messed up")
//            print("Date: " + Date().description)
//            print("FireDate: " + electionTimer.fireDate.description)
//            resetElectionTimer()
//            return
//        }
    }
    
    func electionTimeout() {
        print(cluster.selfIp)
        DispatchQueue.main.async {
            self.roleLabel.text = "Timeout Role Label"
        }
        switch role {
        case Role.Follower:
            startElection()
        case Role.Candidate:
            startElection()
        case Role.Leader: break
        }
    }
    
    func startElection() {
        resetElectionTimer()
        currentTerm = currentTerm + 1
        resetTermVariables()
        becomeCandidate()
        guard let selfIp = cluster.selfIp else {
            print("Failed to get self IP")
            return
        }
        voteGranted?.grantVote(server: selfIp)
        votedFor = selfIp
        guard let voteCount = voteGranted?.getVoteCount() else {
            print("Failed to get vote count")
            return
        }
        if (voteCount >= cluster.majorityCount) {
            becomeLeader()
        } else {
            requestVotes()
        }
    }
    
    func requestVotes() {
        guard let selfIp = cluster.selfIp else {
            print("Failed to get selfIp")
            return
        }
        let lastLogIndex = log.getLastLogIndex()
        guard let lastLogTerm = log.getLogTerm(lastLogIndex) else {
            print("Failed to get last log term")
            return
        }
        guard let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createRequestVoteRequestJson(candidateTerm: currentTerm, lastLogTerm: lastLogTerm, lastLogIndex: lastLogIndex, sender: selfIp)) else {
            print("Failed to create json to send")
            return
        }
        for server in cluster.getPeers() {
            sendJsonUnicast(jsonToSend: jsonToSend, targetHost: server)
        }
    }
    
    func handleRequestVoteRequest(readJson: JsonReader) {
        guard let candidateTerm = readJson.candidateTerm, let lastLogTerm = readJson.lastLogTerm, let lastLogIndex = readJson.lastLogIndex, let sender = readJson.sender, let selfIp = cluster.selfIp else {
            print("Failed to get requestVote variables")
            return
        }
        
        if (currentTerm < candidateTerm) {
            stepDown(term: candidateTerm)
        }
        
        var granted = false
        if (currentTerm == candidateTerm) {
            if (votedFor == nil || votedFor == sender) {
                guard let selfLastLogTerm = log.getLogTerm(log.getLastLogIndex()) else {
                    print("Couldn't get last log term")
                    return
                }
                if (lastLogTerm >= selfLastLogTerm) {
                    if (lastLogIndex >= log.getLastLogIndex()) {
                        granted = true
                        votedFor = sender
                        resetElectionTimer()
                    }
                }
            }
        }
        guard let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createRequestVoteResponseJson(term: currentTerm, granted: granted, sender: selfIp)) else {
            print("Failed to create json to send")
            return
        }
        sendJsonUnicast(jsonToSend: jsonToSend, targetHost: sender)
    }
    
    func handleRequestVoteResponse(readJson: JsonReader) {
        guard let term = readJson.term, let granted = readJson.granted, let sender = readJson.sender else {
            print("Failed to get requestVote variables")
            return
        }
        
        if (currentTerm < term) {
            stepDown(term: term)
        }
        
        if (isCandidate() && currentTerm == term && granted) {
            voteGranted?.grantVote(server: sender)
        }
        
        guard let voteCount = voteGranted?.getVoteCount() else {
            print("Failed to get vote count")
            return
        }
        
        if (voteCount >= cluster.majorityCount) {
            becomeLeader()
        }
    }
}

