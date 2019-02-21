import Foundation
import Security
import CommonCrypto

public struct ReplicantClientModel
{
    public let polish: PolishClientModel
    public var config: ReplicantConfig
    public var toneBurst: ToneBurst?
    
    public init?(withConfig config: ReplicantConfig)
    {
        guard let polish = PolishClientModel(serverPublicKeyData: config.serverPublicKey)
        else
        {
            return nil
        }
        
        if let toneBurst = config.toneBurst
        {
            self.toneBurst = toneBurst.getToneBurst()
        }
        
        self.config = config
        self.polish = polish
    }
}

extension Data
{
    public var bytes: Array<UInt8>
    {
        return Array(self)
    }
}