import Foundation
@main struct MetadataArtworkTests {
 static func main() {
  let art: [String: Any] = ["attributes":["artwork":["url":"https://is1-ssl.mzstatic.com/image/thumb/a/{w}x{h}bb.{f}"]]]
  let exact: [String: Any] = ["data":[["id":"i.opaque", "relationships":["catalog":["data":[art]]]]]]
  precondition(AppleMusicMetadataArtwork.url(exact,size:600)?.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/a/600x600bb.jpg")
  let unrelated: [String: Any] = ["data":[["relationships":["artists":["data":[art]]]]]]
  precondition(AppleMusicMetadataArtwork.url(unrelated,size:600) == nil)
  let evil: [String: Any] = ["data":[["attributes":["artwork":["url":"https://mzstatic.com.evil.test/a"]]]]]
  precondition(AppleMusicMetadataArtwork.url(evil,size:600) == nil)
  print("Apple exact-resource artwork: library/catalog relationship, sizing, unrelated artist and host checks passed")
 }
}
