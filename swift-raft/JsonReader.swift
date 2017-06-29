//
//  JsonReader.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/28/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation
import SwiftyJSON

struct JsonReader {
    var type: String
    var message: String?
    var term: Int?
    var leaderIp: String?
    var candidateTerm: Int?
    var sender: String?
    var lastLogTerm: Int?
    var lastLogIndex: Int?
    var senderCurrentTerm: Int?
    var prevLogIndex: Int?
    var prevLogTerm: Int?
    var leaderCommitIndex: Int?
    var success: Bool?
    var granted: Bool?
    
    init(_ json: JSON) {
        self.type = json["type"].stringValue
        
        switch self.type {
        case "entry":
            self.message = json["message"].stringValue
            self.term = json["term"].intValue
            self.leaderIp = json["leaderIp"].stringValue
        case "redirect":
            self.message = json["message"].stringValue
        case "requestVoteRequest":
            self.candidateTerm = json["candidateTerm"].intValue
            self.lastLogTerm = json["lastLogTerm"].intValue
            self.lastLogIndex = json["lastLogIndex"].intValue
            self.sender = json["sender"].stringValue
        case "requestVoteResponse":
            self.term = json["term"].intValue
            self.granted = json["granted"].boolValue
            self.sender = json["sender"].stringValue
        case "appendEntriesRequest":
            self.leaderIp = json["leaderIp"].stringValue
            self.message = json["message"].stringValue
            self.senderCurrentTerm = json["senderCurrentTerm"].intValue
            self.prevLogIndex = json["prevLogIndex"].intValue
            self.prevLogTerm = json["prevLogTerm"].intValue
            self.leaderCommitIndex = json["leaderCommitIndex"].intValue
        case "appendEntriesResponse":
            self.success = json["success"].boolValue
            self.senderCurrentTerm = json["senderCurrentTerm"].intValue
            self.sender = json["sender"].stringValue
        default: break
        }
    }
}
