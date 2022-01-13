//
//  ReplicantConnectionFactory.swift
//  Replicant
//
//  Created by Adelita Schule on 11/21/18.
//  MIT License
//
//  Copyright (c) 2020 Operator Foundation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Logging

import ReplicantSwift
import SwiftQueue
import Transport
import Transmission
import TransmissionTransport
import Net

open class ReplicantConnectionFactory: ConnectionFactory
{
    public var name: String = "Replicant"
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    let config: ReplicantConfig<SilverClientConfig>
    let log: Logger
        
    public init(config: ReplicantConfig<SilverClientConfig>, log: Logger)
    {
        self.host = NWEndpoint.Host(config.serverIP)
        self.port = NWEndpoint.Port(integerLiteral: config.port)
        self.config = config
        self.log = log
    }
    
    public func connect(using parameters: NWParameters) -> Transport.Connection?
    {
        // FIXME - figure out how to handled NWParameters
        let connectionType = ConnectionType.tcp

        let factory: () -> Transmission.Connection? =
        {
            () -> Transmission.Connection? in

            return ReplicantConnection(type: connectionType, config: self.config, logger: self.log)
        }

        return TransmissionToTransportConnection(factory)
    }
}
