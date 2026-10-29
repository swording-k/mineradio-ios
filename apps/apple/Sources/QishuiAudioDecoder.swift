import Foundation
import CommonCrypto

/// Apple port of the Android qishui-audio-decryptor (GPL-3.0-only).
/// Only accepts the explicit full-sample AES-128-CTR layout used by that adapter.
/// Credentials/keys are ephemeral; never persist decrypted media or log auth.
enum QishuiAudioDecoder {
    struct Result { let data: Data; let fileExtension: String
        var contentType: String { fileExtension == ".flac" ? "audio/flac" : "audio/mp4" }
    }
    enum Failure: Error { case invalidKey, malformedMedia, unsupportedLayout, resourceLimit, crypto }
    static let maximumBytes = 64 * 1024 * 1024
    private struct Box { let type: String; let start: Int; let end: Int; var body: Int { start + 8 } }
    private struct Reader {
        let bytes: [UInt8]
        func u32(_ p: Int) throws -> Int {
            guard p >= 0, p <= bytes.count - 4 else { throw Failure.malformedMedia }
            return bytes[p..<p+4].reduce(0) { ($0 << 8) | Int($1) }
        }
        func boxes(_ start: Int, _ end: Int) throws -> [Box] {
            guard start >= 0, start <= end, end <= bytes.count else { throw Failure.malformedMedia }
            var p = start, result: [Box] = []
            while p < end {
                guard end - p >= 8 else { throw Failure.malformedMedia }
                let size = try u32(p)
                // Extended/zero-sized boxes and fragmented variants are deliberately unsupported.
                guard size >= 8, size <= end - p else { throw Failure.unsupportedLayout }
                let type = String(bytes: bytes[p+4..<p+8], encoding: .ascii) ?? ""
                result.append(Box(type: type, start: p, end: p+size)); p += size
                guard result.count <= 10000 else { throw Failure.resourceLimit }
            }
            return result
        }
        func one(_ type: String, in boxes: [Box]) throws -> Box {
            let matches = boxes.filter { $0.type == type }
            guard matches.count == 1, let b = matches.first else { throw Failure.unsupportedLayout }
            return b
        }
        func child(_ type: String, _ parent: Box) throws -> Box { try one(type, in: boxes(parent.body, parent.end)) }
    }
    static func decode(_ input: Data, auth: String) throws -> Result {
        guard !input.isEmpty, input.count <= maximumBytes else { throw Failure.resourceLimit }
        let key = try resolveKey(auth)
        let r = Reader(bytes: [UInt8](input)), roots = try r.boxes(0, input.count)
        let moov = try r.one("moov", in: roots), mdat = try r.one("mdat", in: roots)
        let trak = try r.child("trak", moov), mdia = try r.child("mdia", trak), minf = try r.child("minf", mdia), stbl = try r.child("stbl", minf)
        let children = try r.boxes(stbl.body, stbl.end)
        let stsd = try r.one("stsd", in: children), stsz = try r.one("stsz", in: children), stsc = try r.one("stsc", in: children), stco = try r.one("stco", in: children)
        let moovChildren = try r.boxes(moov.body, moov.end)
        let senc = try r.one("senc", in: children + moovChildren.filter { $0.type == "senc" })
        guard stsz.end-stsz.body >= 12, senc.end-senc.body >= 8 else { throw Failure.malformedMedia }
        let count = try r.u32(stsz.body+8), fixed = try r.u32(stsz.body+4)
        guard count > 0, count <= 1_000_000 else { throw Failure.resourceLimit }
        guard try r.u32(senc.body) == 0, try r.u32(senc.body+4) == count, senc.end-senc.body == 8+count*8 else { throw Failure.unsupportedLayout }
        guard stsz.end-stsz.body == 12 + (fixed == 0 ? count*4 : 0) else { throw Failure.malformedMedia }
        let sizes = try (0..<count).map { fixed == 0 ? try r.u32(stsz.body+12+$0*4) : fixed }
        let chunks = try r.u32(stco.body+4), mappingCount = try r.u32(stsc.body+4)
        guard chunks > 0, chunks <= count, mappingCount > 0, mappingCount <= chunks,
              stco.end-stco.body == 8+chunks*4, stsc.end-stsc.body == 8+mappingCount*12 else { throw Failure.unsupportedLayout }
        var mappings: [(first: Int, count: Int)] = []
        for i in 0..<mappingCount {
            let p = stsc.body+8+i*12, first = try r.u32(p), n = try r.u32(p+4)
            guard first > (mappings.last?.first ?? 0), first <= chunks, n > 0, n <= count, try r.u32(p+8) == 1 else { throw Failure.unsupportedLayout }
            mappings.append((first,n))
        }
        guard mappings[0].first == 1 else { throw Failure.unsupportedLayout }
        let stsdData = Data(r.bytes[stsd.body..<stsd.end])
        let flacMarker = stsdData.range(of: Data("dfLa".utf8))
        var output = input, plainSamples = Data(), sample = 0, mapping = 0, lastEnd = mdat.body
        for chunk in 1...chunks {
            while mapping+1 < mappings.count && mappings[mapping+1].first <= chunk { mapping += 1 }
            var offset = try r.u32(stco.body+8+(chunk-1)*4)
            guard offset >= lastEnd, offset >= mdat.body, offset <= mdat.end else { throw Failure.malformedMedia }
            for _ in 0..<mappings[mapping].count {
                guard sample < count, sizes[sample] > 0, sizes[sample] <= mdat.end-offset else { throw Failure.malformedMedia }
                let end = offset+sizes[sample], ivStart = senc.body+8+sample*8
                let iv = Array(r.bytes[ivStart..<ivStart+8]) + Array(repeating: UInt8(0), count: 8)
                let plain = try ctr(key: key, iv: iv, input: Array(r.bytes[offset..<end]))
                if flacMarker == nil { output.replaceSubrange(offset..<end, with: plain) }
                else { plainSamples.append(contentsOf: plain) }
                offset = end; sample += 1
            }
            lastEnd = offset
        }
        guard sample == count else { throw Failure.malformedMedia }
        if let marker = flacMarker {
            let at = stsd.body+marker.lowerBound
            guard at >= stsd.body+4 else { throw Failure.malformedMedia }
            let length = try r.u32(at-4)
            guard length >= 12, length <= stsd.end-(at-4) else { throw Failure.malformedMedia }
            var flac = Data("fLaC".utf8)
            flac.append(contentsOf: r.bytes[at+8..<at-4+length]); flac.append(plainSamples)
            return Result(data: flac, fileExtension: ".flac")
        }
        guard let marker = stsdData.range(of: Data("enca".utf8)) else { throw Failure.unsupportedLayout }
        output.replaceSubrange(stsd.body+marker.lowerBound..<stsd.body+marker.upperBound, with: Data("mp4a".utf8))
        return Result(data: output, fileExtension: ".m4a")
    }
    private static func ctr(key: [UInt8], iv: [UInt8], input: [UInt8]) throws -> [UInt8] {
        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBytes { k in iv.withUnsafeBytes { v in
            CCCryptorCreateWithMode(CCOperation(kCCDecrypt), CCMode(kCCModeCTR), CCAlgorithm(kCCAlgorithmAES), CCPadding(ccNoPadding), v.baseAddress, k.baseAddress, key.count, nil, 0, 0, CCModeOptions(kCCModeOptionCTR_BE), &cryptor)
        }}
        guard status == kCCSuccess, let cryptor else { throw Failure.crypto }
        defer { CCCryptorRelease(cryptor) }
        var output = [UInt8](repeating: 0, count: input.count+16), moved = 0
        let done = input.withUnsafeBytes { src in output.withUnsafeMutableBytes { dst in
            CCCryptorUpdate(cryptor, src.baseAddress, input.count, dst.baseAddress, dst.count, &moved)
        }}
        guard done == kCCSuccess, moved == input.count else { throw Failure.crypto }
        return Array(output.prefix(moved))
    }
    private static func resolveKey(_ auth: String) throws -> [UInt8] {
        guard !auth.isEmpty, auth.utf8.count <= 4096 else { throw Failure.invalidKey }
        var hex = auth
        if auth.count != 32 || !auth.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) {
            guard let data = Data(base64Encoded: auth), data.count >= 3 else { throw Failure.invalidKey }
            let bytes = [UInt8](data), padding = Int(bytes[0] ^ bytes[1] ^ bytes[2])-48
            guard padding >= 0, padding <= bytes.count-3 else { throw Failure.invalidKey }
            let inner = Array(bytes[1..<bytes.count-padding]); var decoded: [UInt8] = []
            for i in inner.indices {
                let previous: UInt8 = i == 0 ? 0xfa : i == 1 ? 0x55 : inner[i-2]
                var value = Int(inner[i] ^ previous)-i.nonzeroBitCount-21
                while value < 0 { value += 255 }
                decoded.append(UInt8(value & 255))
            }
            guard let lead = decoded.first else { throw Failure.invalidKey }
            let skip = (48...57).contains(lead) ? Int(lead-48) : (97...122).contains(lead) ? Int(lead-97+10) : 255
            let end = 1+bytes.count-padding-2-skip
            guard end >= 1, end <= decoded.count, let message = String(bytes: decoded[1..<end], encoding: .utf8) else { throw Failure.invalidKey }
            hex = message
        }
        guard hex.count == 32 else { throw Failure.invalidKey }
        let b = Array(hex.utf8); var key: [UInt8] = []
        for i in stride(from: 0, to: b.count, by: 2) {
            guard let n = UInt8(String(bytes: b[i..<i+2], encoding: .ascii) ?? "", radix: 16) else { throw Failure.invalidKey }
            key.append(n)
        }
        return key
    }
}
