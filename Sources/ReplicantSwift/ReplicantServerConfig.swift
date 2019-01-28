//
//  ReplicantServerConfig.swift
//  ReplicantSwift
//
//  Created by Adelita Schule on 12/7/18.
//

import Foundation

public struct ReplicantServerConfig: Codable
{
    public var chunkSize: UInt16
    public var chunkTimeout: Int
    public var addSequences: [SequenceModel]?
    public var removeSequences: [SequenceModel]?
    
    public init?(serverPublicKey: SecKey, chunkSize: UInt16, chunkTimeout: Int, addSequences: [SequenceModel]?, removeSequences: [SequenceModel]?)
    {
        guard chunkSize >= keySize + aesOverheadSize
            else
        {
            print("\nUnable to initialize ReplicantConfig: chunkSize (\(chunkSize)) cannot be smaller than keySize + aesOverheadSize (\(keySize + aesOverheadSize))\n")
            return nil
        }
        self.chunkSize = chunkSize
        self.chunkTimeout = chunkTimeout
        self.addSequences = addSequences
        self.removeSequences = removeSequences
    }
    
    public init?(withConfigAtPath path: String)
    {
        guard let config = ReplicantServerConfig.parseJSON(atPath: path)
        else
        {
            return nil
        }
        
        self = config
    }
    
    /// Creates and returns a JSON representation of the ReplicantServerConfig struct.
    public func createJSON() -> Data?
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do
        {
            let serverConfigData = try encoder.encode(self)
            return serverConfigData
        }
        catch (let error)
        {
            print("Failed to encode Server config into JSON format: \(error)")
            return nil
        }
    }
    
    /// Checks for a valid JSON at the provided path and attempts to decode it into a Replicant server configuration file. Returns a ReplicantConfig struct if it is successful
    /// - Parameters:
    ///     - path: The complete path where the config file is located.
    /// - Returns: The ReplicantServerConfig struct that was decoded from the JSON file located at the provided path, or nil if the file was invalid or missing.
    static public func parseJSON(atPath path: String) -> ReplicantServerConfig?
    {
        let filemanager = FileManager()
        let decoder = JSONDecoder()
        
        guard let jsonData = filemanager.contents(atPath: path)
        else
        {
            print("\nUnable to get JSON data at path: \(path)\n")
            return nil
        }
        
        do
        {
            let config = try decoder.decode(ReplicantServerConfig.self, from: jsonData)
            return config
        }
        catch (let error)
        {
            print("\nUnable to decode JSON into ReplicantServerConfig: \(error)\n")
            return nil
        }
    }

}
