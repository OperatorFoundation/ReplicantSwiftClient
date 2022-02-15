//
//  ReplicantTransmissionConnection.swift
//  Shapeshifter-Swift-Transports
//
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

import Crypto
import Net
import Transmission

open class ReplicantConnection: ReplicantBaseConnection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var config: ReplicantConfig
    public var replicantClientModel: ReplicantClientModel


    public convenience init?(type: ConnectionType, config: ReplicantConfig, logger: Logger)
    {
        guard let newConnection = TransmissionConnection(host: config.serverIP, port: Int(config.port), type: .tcp, logger: logger)
        else
        {
            logger.error("Failed to create replicant connection. NetworkConnectionFactory.connect returned nil.")
            return nil
        }

        self.init(connection: newConnection, config: config, logger: logger)
    }

    public init?(connection: Transmission.Connection,
                 config: ReplicantConfig,
                 logger: Logger)
    {
        let newReplicant = ReplicantClientModel(withConfig: config, logger: logger)
        
        self.config = config
        self.replicantClientModel = newReplicant
        
        super.init(log: logger, network: connection)

        if let polish = replicantClientModel.polish, let polishConfig = replicantClientModel.config.polish
        {
            self.unencryptedChunkSize = polish.chunkSize - UInt16(payloadLengthOverhead)
            
            // Figure out which flavor of polish we are using
            switch (polishConfig)
            {
                // Currently silver is all there is, make sure we have a valid one
                case .silver:
                    if let silverConnection = polish as? SilverClientConnection
                    {
                        self.polishConnection = silverConnection
                    }
            }
        }
    }

    public func cancel()
    {
        // TODO: network.cancel()

        if let stateUpdate = self.stateUpdateHandler
        {
            stateUpdate(NWConnection.State.cancelled)
        }

        if let viabilityUpdate = self.viabilityUpdateHandler
        {
            viabilityUpdate(false)
        }
    }
}

enum ToneBurstError: Error
{
    case generateFailure
    case removeFailure
}

enum IntroductionsError: Error
{
    case nilStateHandler
}
