import Foundation
import CryptoKit
import CommonCrypto
import Security

/// Protocol port of NeteaseCloudMusicApi util/crypto.js (MIT; see bundled notices).
/// This is the public protocol key, not a user credential.
enum NeteaseEAPI {
    static func weapi(json: String, secret: String? = nil) throws -> [String: String] {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let key = secret ?? String((0..<16).map { _ in alphabet.randomElement()! })
        guard key.utf8.count == 16 else { throw URLError(.cannotDecodeContentData) }
        func aes(_ text: String, _ key: String) throws -> String {
            let input = Data(text.utf8), keyData = Data(key.utf8), iv = Data("0102030405060708".utf8)
            var output = Data(count: input.count + kCCBlockSizeAES128)
            let capacity = output.count
            var count = 0
            let status = output.withUnsafeMutableBytes { out in
                input.withUnsafeBytes { bytes in
                    keyData.withUnsafeBytes { k in
                        iv.withUnsafeBytes { ivBytes in
                            CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                    k.baseAddress, keyData.count, ivBytes.baseAddress, bytes.baseAddress, input.count,
                                    out.baseAddress, capacity, &count)
                        }
                    }
                }
            }
            guard status == kCCSuccess else { throw URLError(.cannotDecodeContentData) }
            return output.prefix(count).base64EncodedString()
        }
        let publicDER = Data(base64Encoded: "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ37BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvaklV8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44oncaTWz7OBGLbCiK45wIDAQAB")!
        // Strip the fixed SubjectPublicKeyInfo wrapper of the upstream protocol key.
        guard let rsa = SecKeyCreateWithData(Data(publicDER.dropFirst(22)) as CFData,
            [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic,
             kSecAttrKeySizeInBits: 1024] as CFDictionary, nil) else { throw URLError(.cannotDecodeContentData) }
        var input = Data(repeating: 0, count: 112)
        input.append(Data(key.reversed().map { String($0) }.joined().utf8))
        guard let encrypted = SecKeyCreateEncryptedData(rsa, .rsaEncryptionRaw, input as CFData, nil) as Data? else { throw URLError(.cannotDecodeContentData) }
        return ["params": try aes(aes(json, "0CoJUm6Qyw8W8jud"), key),
                "encSecKey": encrypted.map { String(format: "%02x", $0) }.joined()]
    }
    static func encrypt(path: String, json: String) throws -> String {
        let digest = Insecure.MD5.hash(data: Data("nobody\(path)use\(json)md5forencrypt".utf8))
            .map { String(format: "%02x", $0) }.joined()
        let input = Data("\(path)-36cd479b6b5-\(json)-36cd479b6b5-\(digest)".utf8)
        let key = Data("e82ckenh8dichen8".utf8)
        var output = Data(count: input.count + kCCBlockSizeAES128)
        var count = 0
        let capacity = output.count
        let status = output.withUnsafeMutableBytes { out in
            input.withUnsafeBytes { bytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, key.count, nil, bytes.baseAddress, input.count,
                            out.baseAddress, capacity, &count)
                }
            }
        }
        guard status == kCCSuccess else { throw URLError(.cannotDecodeContentData) }
        return output.prefix(count).map { String(format: "%02X", $0) }.joined()
    }
}
