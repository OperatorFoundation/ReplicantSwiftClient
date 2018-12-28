//
//  ReplicantConfig.swift
//  ReplicantSwift
//
//  Created by Adelita Schule on 11/14/18.
//

import Foundation

public struct ReplicantConfig: Codable
{
    public var serverPublicKey: Data
    public var chunkSize: UInt16
    public var chunkTimeout: Int
    public var addSequences: [SequenceModel]?
    public var removeSequences: [SequenceModel]?
    
    public init?(serverPublicKey: Data, chunkSize: UInt16, chunkTimeout: Int, addSequences: [SequenceModel]?, removeSequences: [SequenceModel]?)
    {
        guard chunkSize >= keySize + aesOverheadSize
        else
        {
            print("\nUnable to initialize ReplicantConfig: chunkSize (\(chunkSize)) cannot be smaller than keySize + aesOverheadSize (\(keySize + aesOverheadSize))\n")
            return nil
        }
        self.serverPublicKey = serverPublicKey
        self.chunkSize = chunkSize
        self.chunkTimeout = chunkTimeout
        self.addSequences = addSequences
        self.removeSequences = removeSequences
    }
    
    /// Creates and returns a JSON representation of the ReplicantConfig struct.
    public func createJSON() -> Data?
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do
        {
            let configData = try encoder.encode(self)
            return configData
        }
        catch (let error)
        {
            print("Failed to encode config into JSON format: \(error)")
            return nil
        }
    }
    
    /// Checks for a valid JSON at the provided path and attempts to decode it into a Replicant client configuration file. Returns a ReplicantConfig struct if it is successful
    /// - Parameters:
    ///     - path: The complete path where the config file is located.
    /// - Returns: The ReplicantConfig struct that was decoded from the JSON file located at the provided path, or nil if the file was invalid or missing.
    static public func parseJSON(atPath path: String) -> ReplicantConfig?
    {
        let fileManager = FileManager()
        let decoder = JSONDecoder()
        
        guard let jsonData = fileManager.contents(atPath: path)
        else
        {
            print("\nUnable to get JSON data at pathe: \(path)\n")
            return nil
        }
        
        do
        {
            let config = try decoder.decode(ReplicantConfig.self, from: jsonData)
            return config
        }
        catch (let error)
        {
            print("\nUnable to decode JSON into ReplicantConfig: \(error)\n")
            return nil
        }
    }
}
