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
  precondition(AppleMusicMetadataArtwork.catalogID(["id":"98765","isLibrary":true]) == nil)
  precondition(AppleMusicMetadataArtwork.catalogID(["id":"98765","isLibrary":true,"catalogId":1464549657]) == "1464549657")
  let response: [String: Any] = ["results":[["kind":"song","trackId":100,"artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg"]]]
  precondition(AppleMusicMetadataArtwork.storeArtwork(response,id:"100",size:600)?.lastPathComponent == "600x600bb.jpg")
  precondition(AppleMusicMetadataArtwork.storeArtwork(response,id:"101",size:600) == nil)
  precondition(!AppleMusicMetadataArtwork.sameRelease(["Song","Band","Studio"], ["Song","Band","Live"], duration:197,otherDuration:197))
  precondition(AppleMusicMetadataArtwork.sameRelease(["Song","Band","Album"], ["song","band","Album"], duration:197,otherDuration:198))
  print("Apple exact-resource artwork: library/catalog relationship, sizing, unrelated artist and host checks passed")
 }
}
