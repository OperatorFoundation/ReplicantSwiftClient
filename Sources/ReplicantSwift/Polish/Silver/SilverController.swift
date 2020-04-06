//
//  SilverController.swift
//  ReplicantSwift
//
//  Created by Mafalda on 11/14/19.
//

import Foundation
import SwiftQueue
import CryptoKit

public let aesOverheadSize = 113
public var keySize = 65

public struct SilverController
{
    let algorithm: SecKeyAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
    let polishTag = "org.operatorfoundation.replicant.polish".data(using: .utf8)!
    let polishServerTag = "org.operatorfoundation.replicant.polishServer".data(using: .utf8)!
    let serverKeyLabel = "ServerKey"
    
    var logQueue: Queue<String>
    
    public init(logQueue: Queue<String>)
    {
        self.logQueue = logQueue
    }
    
    /// Decode data to get public key. This only decodes key data that is NOT padded.
    public func decodeKey(fromData publicKeyData: Data) -> P256.KeyAgreement.PublicKey?
    {
        return try? P256.KeyAgreement.PublicKey(x963Representation: publicKeyData)
    }
    
    func fetchOrCreateServerKeyPair() ->(privateKey: P256.KeyAgreement.PrivateKey, publicKey: P256.KeyAgreement.PublicKey)?
    {
        // Do we already have a key?
        let searchQuery = generateServerKeySearchQuery(withLabel: serverKeyLabel)
        if let key = retreiveKey(query: searchQuery)
        {
            return (key, key.publicKey)
        }
        
        // We don't?
        // Let's create some and return those
        let privateKey = P256.KeyAgreement.PrivateKey()
        
        // Save the key we stored
        let stored = storeKey(privateKey, label: serverKeyLabel)
        if !stored
        {
            print("😱 Failed to store our new server key.")
            return nil
        }
        return (privateKey, privateKey.publicKey)
    }
    
    func retreiveKey(query: CFDictionary) -> P256.KeyAgreement.PrivateKey?
    {
//        // Seek an elliptic-curve key with a given label.
//        let query = [kSecClass: kSecClassKey,
//                     kSecAttrApplicationLabel: label,
//                     kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
//                     kSecUseDataProtectionKeychain: true,
//                     kSecReturnRef: true] as [String: Any]

        // Find and cast the result as a SecKey instance.
        var item: CFTypeRef?
        var secKey: SecKey
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess: secKey = item as! SecKey
        case errSecItemNotFound: return nil
        case let status:
            print("Keychain read failed: \(status.string)")
            return nil
        }
        
        // Convert the SecKey into a CryptoKit key.
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(secKey, &error) as Data?
        else
        {
            print(error.debugDescription)
            return nil
        }
        
        do {
            let key = try P256.KeyAgreement.PrivateKey(x963Representation: data)
            return key
        }
        catch let keyError
        {
            print("Error decoding key: \(keyError)")
            return nil
        }
    }
    
    func storeKey(_ key: P256.KeyAgreement.PrivateKey, label: String) -> Bool
    {
        
        let attributes = [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                          kSecAttrKeyClass: kSecAttrKeyClassPrivate] as [String: Any]

        // Get a SecKey representation.
        var error: Unmanaged<CFError>?
        let keyData = key.x963Representation as CFData
        guard let secKey = SecKeyCreateWithData(keyData,
                                                attributes as CFDictionary,
                                                &error)
            else
        {
            print("Unable to create SecKey representation.")
            if let secKeyError = error
            {
                print(secKeyError)
            }
            return false
        }
        
        // Describe the add operation.
        let query = [kSecClass: kSecClassKey,
                     kSecAttrApplicationLabel: label,
                     kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
                     kSecUseDataProtectionKeychain: true,
                     kSecValueRef: secKey] as [String: Any]

        // Add the key to the keychain.
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            return true
        default:
            if let statusString = SecCopyErrorMessageString(status, nil)
            {
                print("Unable to store item: \(statusString)")
            }
            
            return false
        }

    }
    
    func deleteClientKeys()
    {
        logQueue.enqueue("\nAttempted to delete key from secure enclave.")
        //Remove client keys from secure enclave
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationTag as String: polishTag]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        
        switch deleteStatus
        {
        case errSecItemNotFound:
            logQueue.enqueue("Could not find a client key to delete.\n")
        case noErr:
            logQueue.enqueue("Deleted client keys.\n")
        default:
            logQueue.enqueue("Unexpected status: \(deleteStatus.description)\n")
        }
    }
    
    func generateClientKeyAttributesDictionary() -> CFDictionary
    {
        //FIXME: Secure Enclave
        //let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAlwaysThisDeviceOnly, .privateKeyUsage, nil)!
        
        let privateKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: polishTag
            //kSecAttrAccessControl as String: access
        ]
        
        let publicKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: polishTag
        ]
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            //kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: privateKeyAttributes,
            kSecPublicKeyAttrs as String: publicKeyAttributes
        ]
        
        return attributes as CFDictionary
    }
    
    func generateServerKeyAttributesDictionary() -> CFDictionary
    {
        //FIXME: Secure Enclave
        // let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAlwaysThisDeviceOnly, .privateKeyUsage, nil)!
        
        let privateKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: polishServerTag
            //kSecAttrAccessControl as String: access
        ]
        
        let publicKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: polishServerTag
        ]
        
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            //kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: privateKeyAttributes,
            kSecPublicKeyAttrs as String: publicKeyAttributes
        ]
        
        return attributes as CFDictionary
    }
    
    func generateServerKeySearchQuery(withLabel label: String) -> CFDictionary
    {
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationLabel as String: label,
                                    kSecAttrApplicationTag as String: polishServerTag,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnRef as String: true,
                                    kSecReturnAttributes as String: false,
                                    kSecReturnData as String: false]
        
        return query as CFDictionary
    }
    
    /// This is the format needed to send the key to the server.
    public func generateAndEncryptPaddedKeyData(fromPublicKey publicKey: P256.KeyAgreement.PublicKey, chunkSize: UInt16, privateKey: P256.KeyAgreement.PrivateKey, serverPublicKey: P256.KeyAgreement.PublicKey, salt: Data) -> ChaChaPoly.SealedBox?
    {
        // Encode key as data
        var newKeyData = publicKey.x963Representation
        keySize = newKeyData.count
        
        // Add padding if needed
        if let padding = getKeyPadding(chunkSize: chunkSize, keySize: keySize)
        {
            newKeyData += padding
        }
        
        // Encrypt the key
        guard let encryptedKeyData = encrypt(payload: newKeyData, usingReceiverPublicKey: serverPublicKey, senderPrivateKey: privateKey, andSalt: salt)
        else
        {
            return nil
        }
        
        return encryptedKeyData
    }
    
    //MARK: Encryption
    
    /// Encrypt payload
    public func encrypt(payload: Data, usingReceiverPublicKey receiverPublicKey: P256.KeyAgreement.PublicKey, senderPrivateKey:P256.KeyAgreement.PrivateKey, andSalt salt: Data) -> ChaChaPoly.SealedBox?
    {
        do
        {
            let sharedSecret = try senderPrivateKey.sharedSecretFromKeyAgreement(with: receiverPublicKey)
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt, sharedInfo: Data(), outputByteCount: 32)
            
            do
            {
                let cipherText = try ChaChaPoly.seal(payload, using: symmetricKey)
                return cipherText
            }
            catch let cipherError
            {
                print("Error encrypting payload: \(cipherError)")
                return nil
            }
        }
        catch let sharedSecretError
        {
            print("Unable to encrypt payload. Failed to generate a shared secret: \(sharedSecretError)")
            return nil
        }
    }
    
    /// Decrypt payload
    /// - Parameter payload: Data
    /// - Parameter privateKey: SecKey
    public func decrypt(payload: ChaChaPoly.SealedBox, usingReceiverPrivateKey receiverPrivateKey: P256.KeyAgreement.PrivateKey, senderPublicKey: P256.KeyAgreement.PublicKey, andSalt salt: Data) -> Data?
    {
        do
        {
            let sharedSecret = try receiverPrivateKey.sharedSecretFromKeyAgreement(with: senderPublicKey)
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt, sharedInfo: Data(), outputByteCount: 32)
            
            do
            {
                let decryptedMessage = try ChaChaPoly.open(payload, using: symmetricKey)
                return decryptedMessage
            }
            catch let decryptionError
            {
                print("Error decrypting payload: \(decryptionError)")
            }
        }
        catch let sharedSecretError
        {
            print("Unable to decrypt payload. Error generating shared secret: \(sharedSecretError)")
            return nil
        }
        
        return nil
    }
    
    func getKeyPadding(chunkSize: UInt16, keySize: Int) -> Data?
    {
        let paddingSize = Int(chunkSize) - (keySize + aesOverheadSize)
        if paddingSize > 0
        {
            let bytes = [UInt8](repeating: 0, count: paddingSize)
            return Data(array: bytes)
        }
        else
        {
            return nil
        }
    }
    
}

protocol SecKeyConvertible: CustomStringConvertible {
    /// Creates a key from an X9.63 representation.
    init<Bytes>(x963Representation: Bytes) throws where Bytes: ContiguousBytes
    
    /// An X9.63 representation of the key.
    var x963Representation: Data { get }
}

extension P256.KeyAgreement.PrivateKey: SecKeyConvertible {
    public var description: String {
        return "P256 Key"
    }
}