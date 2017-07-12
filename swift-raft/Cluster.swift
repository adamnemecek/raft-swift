//
//  Cluster.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/29/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import Foundation

class Cluster {
    var leaderIp: String
    var cluster: [String]
    var selfIp: String?
    var majorityCount: Int
    
    init() {
        cluster = ["192.168.10.57", "192.168.10.58", "192.168.10.60"]
//        cluster = ["192.168.10.57", "192.168.10.58"]
        leaderIp = ""
        majorityCount = cluster.count/2
        selfIp = getIFAddresses()[1]
    }
    
    // Get current device IP
    func getIFAddresses() -> [String] {
        var addresses = [String]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        
        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        addresses.append(address)
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return addresses
    }
    
    func getPeers() -> [String] {
        var peers = [String]()
        for server in cluster {
            if (server != selfIp) {
                peers.append(server)
            }
        }
        return peers
    }
    
    func updateLeaderIp(_ ip: String) {
        leaderIp = ip
    }
}
