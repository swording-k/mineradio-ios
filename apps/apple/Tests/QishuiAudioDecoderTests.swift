import Foundation
@main struct QishuiAudioDecoderTests {
 static func main() throws {
  do {
   let result = try QishuiAudioDecoder.decode(Data(base64Encoded: "AAAADGZ0eXBNNEEgAAAAnG1vb3YAAACUdHJhawAAAIxtZGlhAAAAhG1pbmYAAAB8c3RibAAAABRzdHNkAAAAAAAAAABlbmNhAAAAGHN0c3oAAAAAAAAAAAAAAAEAAAA7AAAAHHN0c2MAAAAAAAAAAQAAAAEAAAABAAAAAQAAABRzdGNvAAAAAAAAAAEAAACwAAAAGHNlbmMAAAAAAAAAAQECAwQFBgcIAAAAQ21kYXTyAuhJaKN5PQYXijJbSy++MBTNqbXyBClax1UUlRCkHvLRuLQ784C6Qxjz21thUNdRnPvctTUStXRRjw==")!, auth: "00112233445566778899aabbccddeeff")
   precondition(result.data == Data(base64Encoded: "AAAADGZ0eXBNNEEgAAAAnG1vb3YAAACUdHJhawAAAIxtZGlhAAAAhG1pbmYAAAB8c3RibAAAABRzdHNkAAAAAAAAAABtcDRhAAAAGHN0c3oAAAAAAAAAAAAAAAEAAAA7AAAAHHN0c2MAAAAAAAAAAQAAAAEAAAABAAAAAQAAABRzdGNvAAAAAAAAAAEAAACwAAAAGHNlbmMAAAAAAAAAAQECAwQFBgcIAAAAQ21kYXRTeW50aGV0aWMgc2FtcGxlIHBheWxvYWQgZm9yIGxpY2Vuc2VkIGRlY29kZXIgdmVyaWZpY2F0aW9uLg==")!)
   precondition(result.fileExtension == ".m4a")
  }
  do {
   let result = try QishuiAudioDecoder.decode(Data(base64Encoded: "AAAADGZ0eXBNNEEgAAAAr21vb3YAAACndHJhawAAAJ9tZGlhAAAAl21pbmYAAACPc3RibAAAACdzdHNkAAAAAAAAAABlbmNhAAAAE2RmTGEAAAAAgAAAAwECAwAAABhzdHN6AAAAAAAAAAAAAAABAAAAOwAAABxzdHNjAAAAAAAAAAEAAAABAAAAAQAAAAEAAAAUc3RjbwAAAAAAAAABAAAAwwAAABhzZW5jAAAAAAAAAAEBAgMEBQYHCAAAAENtZGF08gLoSWijeT0GF4oyW0svvjAUzam18gQpWsdVFJUQpB7y0bi0O/OAukMY89tbYVDXUZz73LU1ErV0UY8=")!, auth: "00112233445566778899aabbccddeeff")
   precondition(result.data == Data(base64Encoded: "ZkxhQ4AAAAMBAgNTeW50aGV0aWMgc2FtcGxlIHBheWxvYWQgZm9yIGxpY2Vuc2VkIGRlY29kZXIgdmVyaWZpY2F0aW9uLg==")!)
   precondition(result.fileExtension == ".flac")
  }
  do {
   let result = try QishuiAudioDecoder.decode(Data(base64Encoded: "AAAADGZ0eXBNNEEgAAAAnG1vb3YAAACUdHJhawAAAIxtZGlhAAAAhG1pbmYAAAB8c3RibAAAABRzdHNkAAAAAAAAAABlbmNhAAAAGHN0c3oAAAAAAAAAAAAAAAEAAAA7AAAAHHN0c2MAAAAAAAAAAQAAAAEAAAABAAAAAQAAABRzdGNvAAAAAAAAAAEAAACwAAAAGHNlbmMAAAAAAAAAAQECAwQFBgcIAAAAQ21kYXTyAuhJaKN5PQYXijJbSy++MBTNqbXyBClax1UUlRCkHvLRuLQ784C6Qxjz21thUNdRnPvctTUStXRRjw==")!, auth: "nrwT+lu9EvRZvRL2X7oR9EG5DvZfpibfXaYm3VuhJd+loyoA")
   precondition(result.data == Data(base64Encoded: "AAAADGZ0eXBNNEEgAAAAnG1vb3YAAACUdHJhawAAAIxtZGlhAAAAhG1pbmYAAAB8c3RibAAAABRzdHNkAAAAAAAAAABtcDRhAAAAGHN0c3oAAAAAAAAAAAAAAAEAAAA7AAAAHHN0c2MAAAAAAAAAAQAAAAEAAAABAAAAAQAAABRzdGNvAAAAAAAAAAEAAACwAAAAGHNlbmMAAAAAAAAAAQECAwQFBgcIAAAAQ21kYXRTeW50aGV0aWMgc2FtcGxlIHBheWxvYWQgZm9yIGxpY2Vuc2VkIGRlY29kZXIgdmVyaWZpY2F0aW9uLg==")!)
  }
  for value in [Data(), Data(repeating: 0, count: 20), Data([0,0,0,1,109,111,111,118])] {
   do { _ = try QishuiAudioDecoder.decode(value, auth: "00112233445566778899aabbccddeeff"); preconditionFailure("Malformed MP4 accepted") } catch {}
  }
  do { _ = try QishuiAudioDecoder.decode(Data([1]), auth: "bad"); preconditionFailure("Invalid auth accepted") } catch {}
  print("Qishui decoder: Android synthetic M4A/FLAC differential fixtures and malformed input rejection passed")
 }
}
