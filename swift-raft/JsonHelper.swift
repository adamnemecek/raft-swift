//
//  JsonHelper.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/28/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation
import SwiftyJSON

class JsonHelper {
    enum JsonError: Error {
        case couldNotConvertJsonToData
    }
    
    static func createLogEntryJson(message: String, term: Int, leaderIp: String) -> JSON {
        let logEntryJson: JSON = [
            "type": "entry",
            "message": message,
            "term": term,
            "leaderIp": leaderIp
        ]
        
        return logEntryJson
    }
    
    static func createRedirectMessageJson(_ message: String) -> JSON {
        // Potentially need a term?
        let redirectJson: JSON = [
            "type": "redirect",
            "message": message,
        ]
        
        return redirectJson
    }
    
    static func createRequestVoteRequestJson(candidateTerm: Int, lastLogTerm: Int, lastLogIndex: Int, sender: String) -> JSON {
        let requestJson: JSON = [
            "type": "requestVoteRequest",
            "candidateTerm": candidateTerm,
            "lastLogTerm": lastLogTerm,
            "lastLogIndex": lastLogIndex,
            "sender": sender
        ]
        
        return requestJson
    }
    
    static func createRequestVoteResponseJson(term: Int, granted: Bool, sender: String) -> JSON {
        let responseJson: JSON = [
            "type": "requestVoteResponse",
            "term": term,
            "granted": granted,
            "sender": sender
        ]
        
        return responseJson
    }

    static func createAppendEntriesRequestJson(leaderIp: String, message: String, senderCurrentTerm: Int, prevLogIndex: Int, prevLogTerm: Int, leaderCommitIndex: Int, sender: String) -> JSON {
        let requestJson : JSON = [
            "type": "appendEntriesRequest",
            "leaderIp": leaderIp,
            "message": message,
            "senderCurrentTerm": senderCurrentTerm,
            "prevLogIndex": prevLogIndex,
            "prevLogTerm": prevLogTerm,
            "leaderCommitIndex": leaderCommitIndex,
            "sender": sender
        ]
        
        return requestJson
    }
    
    static func createAppendEntriesResponseJson(success: Bool, senderCurrentTerm: Int, sender: String, matchIndex: Int) -> JSON {
        let responseJson: JSON = [
            "type": "appendEntriesResponse",
            "success": success,
            "senderCurrentTerm": senderCurrentTerm,
            "sender": sender,
            "matchIndex": matchIndex
        ]
        
        return responseJson
    }
    
    static func createUserInfo(peer: String) -> JSON {
        let userInfo: JSON = [
            "type": "userInfo",
            "peer": peer
        ]
        
        return userInfo
    }
    
    static func convertJsonToData(_ json: JSON) -> Data? {
        if let jsonData = json.rawString()?.data(using: String.Encoding.utf8) {
            return jsonData
        }
        
        return nil
    }
    
    static func convertDataToJson(_ data: Data) -> JSON {
        return JSON(data: data)
    }
}
