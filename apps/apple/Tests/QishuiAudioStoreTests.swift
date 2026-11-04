import Foundation
private actor Fixture {
 var calls = 0
 func download(_ url: URL, _ limit: Int) throws -> URL {
  calls += 1
  let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try Data([0,1,2,3,4,5]).write(to: file); return file
 }
}
private final class Clock { var time = Date() }
@main struct QishuiAudioStoreTests {
 static func main() async throws {
  let fixture = Fixture()
  let store = QishuiAudioStore(download: { try await fixture.download($0,$1) }, decode: { data, auth in
   precondition(auth == "fixture-auth"); return .init(data: data, contentType: "audio/mp4")
  })
  let key = try await store.register(remoteURL: URL(string:"https://music.douyincdn.com/a.m4a")!, auth:"fixture-auth")
  precondition(!key.contains("fixture-auth"))
  let reused = try await store.register(remoteURL: URL(string:"https://music.douyincdn.com/a.m4a")!, auth:"fixture-auth")
  precondition(reused == key, "same authorized source should reuse its live ticket")
  let churnFixture = Fixture()
  let churn = QishuiAudioStore(download: { try await churnFixture.download($0,$1) }, decode: { data, _ in .init(data:data,contentType:"audio/mp4") })
  var first = "", last = ""
  for index in 0..<40 {
   let ticket = try await churn.register(remoteURL: URL(string:"https://music.douyincdn.com/track-\(index).m4a")!, auth:"fixture-auth")
   if index == 0 { first = ticket }; last = ticket
  }
  do { _ = try await churn.response(ticket:first); preconditionFailure() } catch QishuiAudioStore.Failure.missingTicket {}
  let latest = try await churn.response(ticket:last); precondition(latest.status == 200)
  await churn.clear()
  let range = try await store.response(ticket:key,range:"bytes=1-3")
  precondition(range.status == 206 && range.data == Data([1,2,3]) && range.headers["Content-Range"] == "bytes 1-3/6")
  let suffix = try await store.response(ticket:key,range:"bytes=-2")
  precondition(suffix.data == Data([4,5]))
  let head = try await store.response(ticket:key,method:"HEAD")
  precondition(head.data.isEmpty && head.headers["Content-Length"] == "6")
  let invalid = try await store.response(ticket:key,range:"bytes=8-9")
  precondition(invalid.status == 416)
  let calls = await fixture.calls; precondition(calls == 1)
  do { _ = try await store.response(ticket:"fake"); preconditionFailure() } catch QishuiAudioStore.Failure.missingTicket {}
  do { _ = try await store.register(remoteURL:URL(string:"https://evil.test/a")!,auth:"fixture-auth"); preconditionFailure() } catch QishuiAudioStore.Failure.invalidSource {}
  await store.clear()
  do { _ = try await store.response(ticket:key); preconditionFailure() } catch QishuiAudioStore.Failure.missingTicket {}
  let small = QishuiAudioStore(limit: 3, download: { try await fixture.download($0,$1) }, decode: { data, _ in .init(data:data,contentType:"audio/mp4") })
  let other = try await small.register(remoteURL:URL(string:"https://music.douyincdn.com/a")!,auth:"x")
  do { _ = try await small.response(ticket:other); preconditionFailure() } catch QishuiAudioStore.Failure.tooLarge {}
  await small.clear()
  let clock = Clock()
  let expiring = QishuiAudioStore(now: { clock.time }, download: { try await fixture.download($0,$1) }, decode: { data, _ in .init(data:data,contentType:"audio/mp4") })
  let old = try await expiring.register(remoteURL:URL(string:"https://music.douyincdn.com/a")!,auth:"x")
  clock.time = clock.time.addingTimeInterval(301)
  do { _ = try await expiring.response(ticket:old); preconditionFailure() } catch QishuiAudioStore.Failure.missingTicket {}
  precondition(QishuiAudioStore.slice("bytes=0-1,3-4", count:6) == nil)
  print("Qishui audio store: opaque tickets, bounded cache, Range/HEAD, invalid hosts, cleared tickets and size cap passed")
 }
}
