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
import Stevia
import FontAwesome_swift

class ViewController: UIViewController, GCDAsyncUdpSocketDelegate, UITableViewDelegate, UITableViewDataSource {
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
    var decrementTimer = Timer()
    var electionTimeoutSeconds = 12
    var heartbeatTimeoutSeconds = 2
    enum Role {
        case Follower
        case Candidate
        case Leader
    }
    
    // MARK: Socket Variables
    
    var udpUnicastSocket: GCDAsyncUdpSocket?
    
    // MARK: View Variables
    var raftView = RaftView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = .init(rawValue: 0)
        // Initialize RpcManager variables
        raftView.log.dataSource = self
        raftView.log.delegate = self

        nextIndex = NextIndex(cluster)
        matchIndex = MatchIndex(cluster)
        voteGranted = VoteGranted(cluster)
        votedFor = nil
        // Initialize Socket variables
        let unicastQueue = DispatchQueue.init(label: "unicast")
        udpUnicastSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: unicastQueue)
        setupUnicastSocket()
        if (cluster.selfIp == "192.168.10.58") {
            electionTimeoutSeconds = 9
            raftView.electionTimer.text = "9"
        } else {
            raftView.electionTimer.text = "12"
        }
        startElectionTimer()
        
        // Selectors for view elements
        updateLogTableView()
        updateStateVariables()
        
        raftView.disconnect.addTarget(self, action: #selector(pressButton), for: .touchUpInside)
        raftView.input.addTarget(self, action: #selector(editInputField), for: .editingDidEnd)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.sv([raftView])
        raftView.fillContainer()
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
            handleRequestVoteResponse(readJson: jsonReader)
        }
    }
    
    // MARK: Update UI Methods
    
    func pressButton() {
        print("Is Valid: " + electionTimer.isValid.description)
        print("FireDate: " + electionTimer.fireDate.description)
        print("Date: " + Date().description)
        print("LeaderIP: " + cluster.leaderIp)
        print("CurrentTerm: " + currentTerm.description )
        print("SelfIP: " + cluster.selfIp!)
        
//        DispatchQueue.main.async {
//            if (self.raftView.disconnect.titleLabel?.text == "Disconnect") {
//                self.raftView.disconnect.titleLabel?.text = "Connect"
//                self.udpUnicastSocket?.close()
//            } else {
//                self.raftView.disconnect.titleLabel?.text = "Disconnect"
//                self.setupUnicastSocket()
//            }
//        }
    }
    
    func flashSendHeartbeat() {
        DispatchQueue.main.async {
            self.raftView.heart.image = UIImage.fontAwesomeIcon(name: .heart, textColor: UIColor.red, size: CGSize(width: 50, height: 50))
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                self.raftView.heart.image = UIImage.fontAwesomeIcon(name: .heart, textColor: UIColor.gray, size: CGSize(width: 50, height: 50))
            })
        }
    }
    
    func flashReceiveHeartbeat() {
        DispatchQueue.main.async {
            self.raftView.heart.image = UIImage.fontAwesomeIcon(name: .heart, textColor: UIColor(red: 0, green: 0.4392, blue: 0.1804, alpha: 1.0) /* #00702e */      , size: CGSize(width: 50, height: 50))
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                self.raftView.heart.image = UIImage.fontAwesomeIcon(name: .heart, textColor: UIColor.gray, size: CGSize(width: 50, height: 50))
            })
        }
    }
    
    func editInputField() {
        guard let msg = raftView.input.text else {
            print("No message")
            return
        }
        receiveClientMessage(msg)
    }
    
    func updateRoleLabel() {
        DispatchQueue.main.async {
            if (self.isFollower()) {
                self.raftView.role.text = "Follower"
            } else if (self.isCandidate()) {
                self.raftView.role.text = "Candidate"
            } else {
                self.raftView.role.text = "Leader"
            }
        }
    }
    
    func updateLogTableView() {
        DispatchQueue.main.async {
            self.raftView.log.reloadData()
        }
    }
    
    func updateStateVariables() {
        DispatchQueue.main.async {
            var votedForString = ""
            if ((self.votedFor) != nil) {
                guard let vote = self.votedFor else {
                    print("Some reason broke")
                    return
                }
                votedForString = vote
            }
            self.raftView.currentTermLabel.text = "Current Term: " + self.currentTerm.description
            self.raftView.commitIndexLabel.text = "Commit Index: " + self.log.commitIndex.description
            self.raftView.votedForLabel.text = "Voted For: " + votedForString
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return log.log.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let logEntryCell = tableView.dequeueReusableCell(withIdentifier: "LogEntryCell", for: indexPath as IndexPath) as! LogEntryCell
        guard let msg = log.getLogMessage(indexPath.row) else {
            print("TEARS")
            return logEntryCell
        }
        logEntryCell.message.text = msg
        
        if (indexPath.row <= log.commitIndex) {
            logEntryCell.committed.image = UIImage.fontAwesomeIcon(name: .check, textColor: UIColor(red: 0.102, green: 0, blue: 0.5176, alpha: 1.0) /* #1a0084 */, size: CGSize(width: 80, height: 80))
        } else {
            logEntryCell.committed.image = UIImage.fontAwesomeIcon(name: .times, textColor: UIColor(red: 0.5686, green: 0, blue: 0.1882, alpha: 1.0) /* #910030 */, size: CGSize(width: 80, height: 80))
        }
        
        return logEntryCell
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
        updateStateVariables()
    }
    
    func becomeCandidate() {
        role = Role.Candidate
        updateRoleLabel()
        updateStateVariables()
    }
    
    func becomeLeader() {
        role = Role.Leader
        guard let selfIp = cluster.selfIp else {
            print("Failed to get selfIp")
            return
        }
        cluster.leaderIp = selfIp
        updateRoleLabel()
        updateStateVariables()
        stopHeartbeatTimers()
        for peer in cluster.getPeers() {
            nextIndex?.setNextIndex(server: peer, index: log.getLastLogIndex())
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
            updateLogTableView()
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
            
            guard let prevLogTerm = log.getLogTerm(prevLogIdx), let message = log.getLogMessage(nextIdx), let logEntryTerm = log.getLogTerm(nextIdx) else {
                print("Could not get previous log term and message")
                return
            }
            
            guard let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesRequestJson(leaderIp: cluster.leaderIp, message: message, senderCurrentTerm: currentTerm, prevLogIndex: prevLogIdx, prevLogTerm: prevLogTerm, leaderCommitIndex: log.commitIndex, sender: selfIp, logEntryTerm: logEntryTerm)) else {
                print("Could not create json to send")
                return
            }
            resetHeartbeatTimer(peer: server)
            sendJsonUnicast(jsonToSend: jsonToSend, targetHost: server)
        }
    }
    
    func handleAppendEntriesRequest(readJson: JsonReader) {
        guard let senderTerm = readJson.senderCurrentTerm, let selfIp = cluster.selfIp, let logEntryTerm = readJson.logEntryTerm else {
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
                if (term != logEntryTerm) {
                    guard let message = readJson.message else {
                        print("Fail to get message")
                        return
                    }
                    if (message == "Heartbeat") {
                        flashReceiveHeartbeat()
                    }
                    
                    log.sliceAndAppend(idx: idx, entry: JsonHelper.createLogEntryJson(message: message, term: logEntryTerm, leaderIp: cluster.leaderIp))
                    updateLogTableView()
                    
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
        guard let sendMessage = log.getLogMessage(nextIdx), let selfIp = cluster.selfIp, let logEntryTerm = log.getLogTerm(nextIdx) else {
            print("Failed to get message")
            return
        }
        guard let jsonToSend = JsonHelper.convertJsonToData(JsonHelper.createAppendEntriesRequestJson(leaderIp: cluster.leaderIp, message: sendMessage, senderCurrentTerm: currentTerm, prevLogIndex: prevLogIdx, prevLogTerm: prevLogTerm, leaderCommitIndex: log.commitIndex, sender: selfIp, logEntryTerm: logEntryTerm)) else {
            print("Failed to create json data")
            return
        }
        if (!(sendMessage.range(of: "Heartbeat") != nil)) {
            resetHeartbeatTimer(peer: sender)
        }
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
        let heartbeatEntry = JsonHelper.createLogEntryJson(message: "Heartbeat", term: currentTerm, leaderIp: cluster.leaderIp)
        
        log.addEntryToLog(heartbeatEntry)
        updateLogTableView()
        sendAppendEntriesRequest(nextIdx, peer)
        rpcDue[peer] = Timer.scheduledTimer(timeInterval: TimeInterval(heartbeatTimeoutSeconds), target: self, selector: #selector(sendHeartbeat(timer:)), userInfo: userInfo, repeats: true)
    }
    
    func sendHeartbeat(timer : Timer) {
        guard let peer = JsonReader((timer.userInfo as? JSON)!).peer, let nextIdx = nextIndex?.getNextIndex(peer) else {
            print("Failed to get peer from timer or next index")
            return
        }
        let heartbeatEntry = JsonHelper.createLogEntryJson(message: "Heartbeat", term: currentTerm, leaderIp: cluster.leaderIp)
        
        log.addEntryToLog(heartbeatEntry)
        updateLogTableView()
        sendAppendEntriesRequest(nextIdx, peer)
        flashSendHeartbeat()
    }
    
    func resetHeartbeatTimer(peer: String) {
        let userInfo = JsonHelper.createUserInfo(peer: peer)
        rpcDue[peer]?.invalidate()
        rpcDue[peer] = nil
        rpcDue[peer] = Timer.scheduledTimer(timeInterval: TimeInterval(heartbeatTimeoutSeconds), target: self, selector: #selector(sendHeartbeat(timer:)), userInfo: userInfo, repeats: true)
        print("reset heartbeat timer")
    }
    
    func stopHeartbeatTimers() {
        for server in cluster.getPeers() {
            if (rpcDue[server] != nil) {
                rpcDue[server]?.invalidate()
                rpcDue[server] = nil
            }
        }
    }
    
    func startElectionTimer() {
        electionTimer = Timer.scheduledTimer(timeInterval: TimeInterval(electionTimeoutSeconds), target: self, selector: #selector(self.electionTimeout), userInfo: nil, repeats: true)
        raftView.electionTimer.text = electionTimeoutSeconds.description
        startDecrementTimer()
    }
    
    func startDecrementTimer() {
        decrementTimer.invalidate()
        decrementTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.decrementTimerLabel), userInfo: nil, repeats: true)
    }
    
    func decrementTimerLabel() {
        DispatchQueue.main.async {
            guard let text = self.raftView.electionTimer.text else {
                print("No election timer text")
                return
            }
            guard var seconds = Int(text) else {
                print("Int conversion fail")
                return
            }
            seconds = seconds - 1
            self.raftView.electionTimer.text = seconds.description
        }
    }
    
    func resetElectionTimer() {
        DispatchQueue.main.async {
            self.electionTimer.invalidate()
            self.raftView.electionTimer.text = self.electionTimeoutSeconds.description
            self.startElectionTimer()
        }
    }
    
    func electionTimeout() {
        switch role {
        case Role.Follower:
            print("Election Timeout Follower")
            startElection()
        case Role.Candidate:
            print("Election Timeout Candidate")
            startElection()
        case Role.Leader:
            print("Leader does nothing in timeout")
            resetElectionTimer()
        }
    }
    
    func startElection() {
        if (isFollower() || isCandidate()) {
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
    }
    
    func requestVotes() {
        if (isCandidate()) {
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

