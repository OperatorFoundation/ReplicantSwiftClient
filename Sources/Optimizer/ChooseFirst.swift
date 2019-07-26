//
//  ChooseFirst.swift
//  Optimizer
//
//  Created by Mafalda on 7/26/19.
//

import Foundation
import Transport

struct ChooseFirst: Strategy
{
    func choose(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        return transports.first
    }
    
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int)
    {
        
    }
}
