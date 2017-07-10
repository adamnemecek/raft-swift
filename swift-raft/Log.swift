//
//  Log.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/29/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation
import SwiftyJSON

class Log {
    var log: [JSON]
    var commitIndex: Int
    var lastAppliedIndex: Int
    init() {
        log = [JSON]()
        log.append(JsonHelper.createLogEntryJson(message: "", term: 0, leaderIp: ""))
        commitIndex = 0
        lastAppliedIndex = 0
    }
    
    func addEntryToLog(_ entry: JSON) {
        log.append(entry)
    }
    
    func getLogTerm(_ index: Int) -> Int? {
        if (index < 1 || index >= log.count) {
            return 0
        } else {
            if let term = JsonReader(log[index]).term {
                return term
            }
            return nil
        }
    }
    
    func getLogEntriesString() -> String? {
        var returnString = ""
        for (index, _) in log.enumerated() {
            guard let message = getLogMessage(index) else {
                print("Failed to get message")
                return nil
            }
            if (message != "Heartbeat") {
                returnString = returnString + " " + message
            }
        }
        return returnString
    }
    
    func getLogMessage(_ index: Int) -> String? {
        return JsonReader(log[index]).message
    }
    
    func getLastLogIndex() -> Int {
        return log.count - 1
    }
    
    func getLastLogTerm() -> Int? {
        let lastLogEntry = log[getLastLogIndex()]
        
        if let term = JsonReader(lastLogEntry).term {
            return term
        }
        
        return nil
    }
    
    func sliceAndAppend(idx: Int, entry: JSON) {
        var logSliceArray = Array(log[0...idx - 1])
        logSliceArray.append(entry)
        log = logSliceArray
    }
    
    func updateCommitIndex(_ idx: Int) {
        commitIndex = idx
    }
}
