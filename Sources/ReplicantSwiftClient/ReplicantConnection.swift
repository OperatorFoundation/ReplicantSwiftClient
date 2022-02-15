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

open class ReplicantConnection: Transmission.Connection
{
    public let aesOverheadSize = 113
    public let payloadLengthOverhead = 2
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var config: ReplicantConfig
    public var replicantClientModel: ReplicantClientModel
    public var log: Logger

    var unencryptedChunkSize: UInt16 = 400 // FIXME: unencrypted chunk size for non-polish
    var sendTimer: Timer?
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var sendBufferQueue = DispatchQueue(label: "SendBuffer Queue")
    var bufferLock = DispatchGroup()
    var decryptedReceiveBuffer: Data
    var sendBuffer: Data

    var network: Transmission.Connection

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
    
//    public convenience init?(host: NWEndpoint.Host,
//                             port: NWEndpoint.Port,
//                             type: ConnectionType,
//                             config: ReplicantConfig<SilverClientConfig>,
//                             logger: Logger)
//    {
//        var maybeHostString: String? = nil
//        switch host
//        {
//            case .ipv4(let ipv4):
//                let data = ipv4.rawValue
//                maybeHostString = "\(data[0]).\(data[1]).\(data[2]).\(data[3])"
//            default:
//                maybeHostString = nil
//        }
//        guard let hostString = maybeHostString else {return nil}
//
//        guard let newConnection = TransmissionConnection(host: hostString, port: Int(port.rawValue), type: .tcp, logger: logger)
//        else
//        {
//            logger.error("Failed to create replicant connection. NetworkConnectionFactory.connect returned nil.")
//            return nil
//        }
//
//        self.init(connection: newConnection, config: config, logger: logger)
//    }

    public init?(connection: Transmission.Connection,
                 config: ReplicantConfig,
                 logger: Logger)
    {
        let newReplicant = ReplicantClientModel(withConfig: config, logger: logger)

        self.network = connection
        self.config = config
        self.replicantClientModel = newReplicant
        self.decryptedReceiveBuffer = Data()
        self.sendBuffer = Data()
        self.log = logger

        if let polishConnection = replicantClientModel.polish
        {
            self.unencryptedChunkSize = polishConnection.chunkSize - UInt16(payloadLengthOverhead)
        }

        introductions
        {
            (maybeIntroError) in

            guard maybeIntroError == nil
            else
            {
                logger.error("Error attempting to meet the server during Replicant Connection Init.")
                return
            }

            logger.debug("\nNew Replicant connection is ready. 🎉 \n")
        }
    }

    public func write(data: Data) -> Bool
    {
        log.debug("\n💌 Send called on Replicant connection.")
        if let polishConnection = getPolishConnection()
        {
            // Lock so that the timer cannot fire and change the buffer. Unlock in the network send() callback.
            bufferLock.enter()

            guard data.count > 0 else
            {
                log.error("Received a send command with no content.")
                bufferLock.leave()
                return false
            }

            self.sendBuffer.append(data)

            while self.sendBuffer.count >= (self.unencryptedChunkSize)
            {
                // Stop the timer, we're doing a send.
                if self.sendTimer != nil
                {
                    self.sendTimer!.invalidate()
                    self.sendTimer = nil
                }

                guard self.sendBufferChunk(polishConnection: polishConnection) else
                {
                    bufferLock.leave()
                    return false
                }
            }

            // We left data in the buffer because it was smaller thank a chunk.
            // We'll set a timer and if it hangs around for too long then we'll send it anyway.
            if self.sendBuffer.count > 0
            {
                // Start the timer
                if self.sendBuffer.count > 0
                {
                    self.sendTimer = Timer(timeInterval: TimeInterval(polishConnection.chunkTimeout), repeats: true)
                    {
                        (timer) in

                        self.chunkTimeout()
                    }
                }
            }

            bufferLock.leave()
            return true
        }
        else // No Polish needed, send the data if it's provided
        {
            return network.write(data: data)
        }
    }

    func sendBufferChunk(polishConnection: PolishConnection) -> Bool
    {
        log.debug("Replicant Client called sendBufferChunks")
        // Only encrypt and send over network when chunk size is available, leftovers to the buffer
        guard self.sendBuffer.count >= (unencryptedChunkSize) else {return false}

        let payloadData = self.sendBuffer[0 ..< unencryptedChunkSize]
        let payloadSize = UInt16(unencryptedChunkSize)
        let dataChunk = payloadSize.data + payloadData
        guard let polishedData = polishConnection.polish(inputData: dataChunk) else
        {
            log.error("sendBufferChunks: Failed to polish data. Giving up.")
            return false
        }

        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[unencryptedChunkSize...]

        // Keep calling network.write if the leftover data is at least chunk size
        guard network.write(data: polishedData) else
        {
            self.log.error("Replicant write failed.")
            if self.sendTimer != nil
            {
                self.sendTimer!.invalidate()
                self.sendTimer = nil
            }


            return false
        }

        return true
    }

    public func read(size: Int) -> Data?
    {
        log.debug("\n🙋‍♀️  Replicant connection receive called.\n")

        if let polishConnection = getPolishConnection()
        {
            self.log.debug("polish connection detected!")
            bufferLock.enter()

            // Check to see if we have min length data in decrypted buffer before calling network receive. Skip the call if we do.
            if decryptedReceiveBuffer.count >= size
            {
                // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
                let sliceLength = decryptedReceiveBuffer.count < size ? decryptedReceiveBuffer.count : size

                // Return the requested amount
                let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]

                // Remove what was delivered from the buffer
                self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]

                bufferLock.leave()
                return returnData
            }
            else
            {
                self.log.debug("ReplicantSwiftClient receive called")
                // Read ChunkSize amount of data
                // Check to see if we got data, and that it is the right size
                guard let someData = network.read(size: Int(polishConnection.chunkSize)), someData.count == polishConnection.chunkSize
                else
                {
                    self.log.error("\n🙋‍♀️  Read called but no data was receieved.\n")
                    return nil
                }

                self.log.debug("read from ReplicantSwiftClient receive finished")

                let maybeReturnData = self.handleReceivedData(polishConnection: polishConnection, size: size, encryptedData: someData)

                self.bufferLock.leave()
                return maybeReturnData
            }
        }
        else
        {
            self.log.debug("ReplicantSwiftClient receive called with no polish. minimumincompleteLength: \(size)")
            // Check to see if we got data
            guard let someData = network.read(size: size)
            else
            {
                self.log.error("\n🙋‍♀️  Read called but no data was receieved.\n")
                return nil
            }

            self.log.debug("no polish read from ReplicantSwiftClient receive finished. minimumIncompleteLength\(size), data size: \(someData.count)")
            return someData
        }
    }

    public func read(maxSize: Int) -> Data?
    {
        return self.read(size: maxSize)
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

    /// This takes an optional data and adds it to the buffer before acting on min/max lengths
    func handleReceivedData(polishConnection: PolishConnection, size: Int, encryptedData: Data) -> Data?
    {
        log.debug("Replicant Client called handleReceivedData")
        // Try to decrypt the entire contents of the encrypted buffer
        guard let decryptedData = polishConnection.unpolish(polishedData: encryptedData)
        else
        {
            log.error("Unable to decrypt encrypted receive buffer")
            return nil
        }

        // The first two bytes simply lets us know the actual size of the payload
        // This helps account for cases when the payload must be smaller than chunk size
        guard let uintPayloadSize = decryptedData[..<payloadLengthOverhead].uint16
        else { return nil }
        let payloadSize = Int(uintPayloadSize)
        let payload = decryptedData[payloadLengthOverhead..<payloadSize]

        // Add decrypted data to the decrypted buffer
        self.decryptedReceiveBuffer.append(payload)

        // Check to see if the decrypted buffer meets min/max parameters
        guard decryptedReceiveBuffer.count >= size
        else
        {
            // Not enough data return nothing
            return nil
        }

        // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
        let sliceLength = decryptedReceiveBuffer.count < size ? decryptedReceiveBuffer.count : size

        // Return the requested amount
        let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]

        // Remove what was delivered from the buffer
        self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]

        return returnData
    }

    func voightKampffTest(completion: @escaping (Error?) -> Void)
    {
        // Tone Burst
        if var toneBurst = self.replicantClientModel.toneBurst
        {
            toneBurst.perform(connection: self)
            {
                maybeError in

                completion(maybeError)
            }
        }
        else
        {
            completion(nil)
        }
    }

    func introductions(completion: @escaping (Error?) -> Void)
    {
        voightKampffTest
        {
            (maybeVKError) in

            guard maybeVKError == nil
            else
            {
                self.stateUpdateHandler?(NWConnection.State.cancelled)
                self.log.error("Toneburst error: \(maybeVKError!)")
                completion(maybeVKError)
                return
            }

            if var polishConnection = self.getPolishConnection()
            {
                polishConnection.handshake(connection: self)
                {
                    (maybeHandshakeError) in

                    if let handshakeError = maybeHandshakeError
                    {
                        self.log.error("Received a handshake error: \(handshakeError)")
                        self.stateUpdateHandler?(NWConnection.State.cancelled)
                        completion(handshakeError)
                        return
                    }
                    else
                    {
                        self.log.debug("\n🤝  Client successfully completed handshake. 👏👏👏👏\n")
                        self.stateUpdateHandler?(NWConnection.State.ready)
                        completion(nil)
                    }
                }
            }
            else
            {
                self.log.debug("No need to perform the Replicant handshake with the server, the Polish connection is nil.")
                completion(nil)
            }
        }
    }

    func chunkTimeout()
    {
        // Lock so that send isn't called while we're working
        bufferLock.enter()

        self.sendTimer = nil

        // Double check the buffer to be sure that there is still data in there.
        self.log.debug("\n⏰  Chunk Timeout Reached\n  ⏰")

        let payloadSize = sendBuffer.count

        if let polishConnection = getPolishConnection()
        {
            guard payloadSize > 0, payloadSize < polishConnection.chunkSize
            else
            {
                bufferLock.leave()
                return
            }

            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding
            let maybeEncryptedData = polishConnection.polish(inputData: dataChunk)

            // Buffer should only contain unsent data
            self.sendBuffer = Data()

            // Keep calling network.send if the leftover data is at least chunk size
            if let encryptedData = maybeEncryptedData
            {
                guard network.write(data: encryptedData)
                else
                {
                    self.log.error("Replicant Connection write failed.")
                    self.bufferLock.leave()
                    return
                }

                self.bufferLock.leave()
                return
            }
        }
        else // Replicant without polish
        {
            guard payloadSize > 0
            else
            {
                bufferLock.leave()
                return
            }

            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding

            // Buffer should only contain unsent data
            self.sendBuffer = Data()

            // Keep calling network.send if the leftover data is at least chunk size
            guard network.write(data: dataChunk)
            else
            {
                self.log.error("Replicant Connection write failed.")
                self.bufferLock.leave()
                return
            }

            self.bufferLock.leave()
            return
        }
    }

    public func readWithLengthPrefix(prefixSizeInBits: Int) -> Data?
    {
        if let polishConnection = getPolishConnection()
        {
            self.bufferLock.enter()

            let prefixSizeInBytes = prefixSizeInBits / 8
            guard self.decryptedReceiveBuffer.count > prefixSizeInBytes else
            {
                self.bufferLock.leave()
                return nil
            }

            let lengthData = self.decryptedReceiveBuffer[..<prefixSizeInBytes]
            self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[prefixSizeInBytes...]

            var maybeLength: Int?
            switch prefixSizeInBits
            {
                case 8:
                    guard let length8 = lengthData.maybeNetworkUint8 else
                    {
                        self.bufferLock.leave()
                        return nil
                    }

                    maybeLength = Int(length8)
                case 16:
                    guard let length16 = lengthData.maybeNetworkUint16 else
                    {
                        self.bufferLock.leave()
                        return nil
                    }

                    maybeLength = Int(length16)
                case 32:
                    guard let length32 = lengthData.maybeNetworkUint32 else
                    {
                        self.bufferLock.leave()
                        return nil
                    }

                    maybeLength = Int(length32)
                case 64:
                    guard let length64 = lengthData.maybeNetworkUint64 else
                    {
                        self.bufferLock.leave()
                        return nil
                    }

                    maybeLength = Int(length64)
                default:
                    return nil
            }

            guard let length = maybeLength else {return nil}
            guard self.decryptedReceiveBuffer.count >= length else {return nil}

            let data = self.decryptedReceiveBuffer[..<length]
            self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[length...]

            return data
        }
        else // No Polish
        {
            var maybeSizeData: Int?
            
            switch prefixSizeInBits
            {
                case 8:
                    guard let dataReceived = self.network.read(size: 1) else
                        { return nil }
                    
                    guard let uintReceived = dataReceived.maybeNetworkUint8 else
                        { return nil }
                    
                    maybeSizeData = Int(uintReceived)
                case 16:
                    guard let dataReceived = self.network.read(size: 2) else
                        { return nil }
                    
                    guard let uintReceived = dataReceived.maybeNetworkUint16 else
                        { return nil }
                    
                    maybeSizeData = Int(uintReceived)
                case 32:
                    guard let dataReceived = self.network.read(size: 4) else
                        { return nil }
                    
                    guard let uintReceived = dataReceived.maybeNetworkUint32 else
                        { return nil }
                    
                    maybeSizeData = Int(uintReceived)
                case 64:
                    guard let dataReceived = self.network.read(size: 8) else
                        { return nil }
                    
                    guard let uintReceived = dataReceived.maybeNetworkUint64 else
                        { return nil }
                    
                    maybeSizeData = Int(uintReceived)
                default:
                    return nil
            }
            
            guard let dataSize = maybeSizeData else
            { return nil }
            
            guard let dataReceived = self.network.read(size: dataSize) else
            { return nil }
            
            return dataReceived
        }
    }

    public func write(string: String) -> Bool
    {
        self.write(data: string.data)
    }

    public func writeWithLengthPrefix(data: Data, prefixSizeInBits: Int) -> Bool
    {
        var maybeLengthData: Data? = nil

        let length = data.count
        switch prefixSizeInBits
        {
            case 8:
                let length8 = UInt8(length)
                maybeLengthData = length8.maybeNetworkData
            case 16:
                let length16 = UInt16(length)
                maybeLengthData = length16.maybeNetworkData
            case 32:
                let length32 = UInt32(length)
                maybeLengthData = length32.maybeNetworkData
            case 64:
                let length64 = UInt64(length)
                maybeLengthData = length64.maybeNetworkData
            default:
                return false
        }

        guard let lengthData = maybeLengthData else {return false}

        let totalData = lengthData + data
        return self.write(data: totalData)
    }
    
    func getPolishConnection() -> PolishConnection?
    {
        guard let polish = replicantClientModel.polish
            else { return nil } // No Polish
        
        // Figure out which flavor of polish we are using
        switch (replicantClientModel.config.polish)
        {
            // Currently silver is all there is, make sure we have a valid one
            case .silver:
                if let silverConnection = polish as? SilverClientConnection
                {
                    return silverConnection
                }
                else
                {
                    print("Failed to cast our client connection to a SilverClientConnection")
                    return nil
                }
                
            default:
                print("attempted to write data with an unsupported polish type.")
                return nil
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
