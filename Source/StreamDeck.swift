import Cocoa
import Foundation

final class Plugin {
 var language = "en"
 var translations: [String:String] = [:]
 func configureLanguage(info: [String:Any], resources: URL) {
  let identifier = (info["application"] as? [String:Any])?["language"] as? String ?? "en"
  language = identifier.replacingOccurrences(of:"_",with:"-").lowercased().split(separator:"-").first == "ja" ? "ja" : "en"
  let url = resources.appendingPathComponent(language + ".json")
  let object = (try? Data(contentsOf:url)).flatMap { try? JSONSerialization.jsonObject(with:$0) } as? [String:Any]
  translations = object?["Localization"] as? [String:String] ?? [:]
 }
 func text(_ key:String)->String { translations[key] ?? key }

 var socket: URLSessionWebSocketTask!
 var messageSink: (([String:Any])->Void)?
 var commandSink: ((URL)->Void)?
 var contexts: [String: [String: Any]] = [:]
 var levels: [String: [String: Any]] = [:]
 var slots: [String] = []
 var displayed: [String:String] = [:]
 var locks: [String:Date] = [:]
 var icons: [String:String] = [:]
 var sentIcons: [String:String] = [:]
 var active = false
 var lastState = Date.distantPast
 var observer: NSObjectProtocol?
 var timer: Timer?
 func send(_ event: String, _ context: String, _ payload: [String: Any]) {
  let message: [String: Any] = ["event": event, "context": context, "payload": payload]
  if let sink=messageSink {sink(message);return}
  guard let data = try? JSONSerialization.data(withJSONObject: message), let text = String(data:data,encoding:.utf8) else { return }
  Task { try? await socket.send(.string(text)) }
 }
 func start() {
  let args=CommandLine.arguments
  func arg(_ key:String)->String? { guard let i=args.firstIndex(of:key), i+1<args.count else{return nil}; return args[i+1] }
  guard let port=arg("-port"), let uuid=arg("-pluginUUID"), let event=arg("-registerEvent"), let url=URL(string:"ws://127.0.0.1:\(port)") else { exit(1) }
  let info = arg("-info").flatMap { $0.data(using:.utf8) }.flatMap { try? JSONSerialization.jsonObject(with:$0) } as? [String:Any] ?? [:]
  configureLanguage(info:info,resources:URL(fileURLWithPath:args[0]).deletingLastPathComponent())
  socket=URLSession.shared.webSocketTask(with:url);socket.resume()
  observer=DistributedNotificationCenter.default().addObserver(forName:NSNotification.Name("local.appmixer.state"), object:nil, queue:.main) { [weak self] n in
   guard let self else {return};self.levels=n.userInfo?["levels"] as? [String:[String:Any]] ?? [:]; self.active=n.userInfo?["active"] as? Bool ?? false; self.slots=n.userInfo?["slots"] as? [String] ?? []; self.lastState=Date();self.refresh()
  }
  timer=Timer.scheduledTimer(withTimeInterval:2,repeats:true){[weak self] _ in self?.refresh()}
  Task {
   let data=try! JSONSerialization.data(withJSONObject:["event":event,"uuid":uuid])
   do {try await socket.send(.string(String(data:data,encoding:.utf8)!));while true {let message=try await socket.receive();let data:Data;switch message {case .string(let text):data=Data(text.utf8);case .data(let d):data=d;@unknown default:continue};if let object=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] {await MainActor.run { self.receive(object) }}}} catch {exit(0)}
  }
 }
 func receive(_ m:[String:Any]) {
  guard let event=m["event"] as? String,let context=m["context"] as? String else{return}
  let p=m["payload"] as? [String:Any] ?? [:]
  if event=="willDisappear" {contexts.removeValue(forKey:context);displayed.removeValue(forKey:context);sentIcons.removeValue(forKey:context);locks.removeValue(forKey:context);return}
  if event=="willAppear" || event=="didReceiveSettings" {var data=contexts[context] ?? [:];data["settings"]=p["settings"] ?? [:];if let a=m["action"] {data["action"]=a};if let c=p["controller"]{data["controller"]=c};if let coords=p["coordinates"] as? [String:Int] {data["column"]=coords["column"] ?? 0};contexts[context]=data;refresh();return}
  if event=="sendToPlugin" || event=="propertyInspectorDidAppear" {send("sendToPropertyInspector",context,["apps":levels.map { ["id":$0.key,"name":$0.value["name"] as? String ?? $0.key] }.sorted{ $0["name"]! < $1["name"]! }]);return}
  guard ["keyDown","dialRotate","dialDown","touchTap"].contains(event) else{return}
  let settings=p["settings"] as? [String:Any] ?? contexts[context]?["settings"] as? [String:Any] ?? [:]
  let app=displayed[context] ?? resolve(context,settings)
  guard !app.isEmpty else {send("showAlert",context,[:]);return}
  let action=m["action"] as? String ?? ""
  var op=action.components(separatedBy:".").last ?? "mute"
  let configured=Double("\(settings["step"] ?? 5)") ?? 5
  var step=configured.isFinite ? min(100,max(1,configured)):5
  if event=="dialRotate" {let ticks=p["ticks"] as? Int ?? 0;guard ticks != 0 else{return};op=ticks>0 ? "up":"down";step=min(100,step*Double(abs(ticks)))}
  if event=="dialDown" || event=="touchTap" {op="mute"}
  locks[context]=Date().addingTimeInterval(2)
  guard ["up","down","mute"].contains(op) else{return}
  var url=URLComponents();url.scheme="appmixer";url.host="control";url.queryItems=[URLQueryItem(name:"app",value:app),URLQueryItem(name:"op",value:op),URLQueryItem(name:"step",value:String(step))]
  guard let target=url.url else {return}
  if let sink=commandSink {sink(target);return}
  guard let appURL=NSWorkspace.shared.urlForApplication(withBundleIdentifier:"local.appmixer.desktop") else {send("showAlert",context,[:]);return}
  let config=NSWorkspace.OpenConfiguration();config.activates=false
  NSWorkspace.shared.open([target],withApplicationAt:appURL,configuration:config){[weak self] _,error in if error != nil {self?.send("showAlert",context,[:])}}
 }
 func resolve(_ context:String,_ settings:[String:Any])->String {
  let auto = (contexts[context]?["action"] as? String ?? "").hasSuffix(".auto") || settings["mode"] as? String == "auto"
  if auto {let col=contexts[context]?["column"] as? Int ?? 0;let slot=Int("\(settings["slot"] ?? col)") ?? col;return slots.indices.contains(slot) ? slots[slot]:""}
  return (settings["app"] as? String ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
 }
 func icon(_ app:String)->String {
  if let image=levels[app]?["icon"] as? String, image.hasPrefix("data:image/png;base64,"), image.count<=8192, image.count>22 {return image}
  if let cached=icons[app] {return cached}
  guard let url=NSWorkspace.shared.urlForApplication(withBundleIdentifier:app.hasPrefix("chrome-tab:") ? "com.google.Chrome" : app) else{return "icon.png"}
  let image=NSWorkspace.shared.icon(forFile:url.path)
  guard let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:72,pixelsHigh:72,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),let context=NSGraphicsContext(bitmapImageRep:rep) else{return "icon.png"}
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context;image.draw(in:NSRect(x:0,y:0,width:72,height:72));NSGraphicsContext.restoreGraphicsState()
  guard let png=rep.representation(using:.png,properties:[:]) else{return "icon.png"}
  let result="data:image/png;base64,"+png.base64EncodedString();icons[app]=result;return result
 }
 func refresh() {
  for (context,data) in contexts {
   let settings=data["settings"] as? [String:Any] ?? [:]
   let locked=(locks[context] ?? .distantPast)>Date()
   let app=locked ? displayed[context] ?? resolve(context,settings):resolve(context,settings)
   displayed[context]=app
   let state=levels[app] ?? [:];let label=settings["label"] as? String ?? "";let name=label.isEmpty ? state["name"] as? String ?? (app.isEmpty ? "Prisma":app.components(separatedBy:".").last ?? text("App")) : label
   let volume=(state["volume"] as? NSNumber)?.doubleValue ?? 1;let muted=state["muted"] as? Bool ?? false
   let alive=Date().timeIntervalSince(lastState)<5;let error=state["error"] as? String ?? ""
   let auto=(data["action"] as? String ?? "").hasSuffix(".auto") || settings["mode"] as? String == "auto"
   let status = !alive ? text("Launch Prisma") : !active ? text("Control off") : app.isEmpty ? (auto ? text("Waiting for audio"):text("Select an app")) : !error.isEmpty ? text("Check access") : state["running"] as? Bool != true ? text("Waiting for app") : muted ? text("Muted") : "\(Int((volume*100).rounded()))%"
   let image=app.isEmpty ? "icon.png":icon(app)
   if sentIcons[context] != image {send("setImage",context,["image":image,"target":0]);sentIcons[context]=image}
   if data["controller"] as? String == "Encoder" {send("setFeedback",context,["title":name,"value":status,"icon":image,"indicator":app.isEmpty ? 0:min(100,max(0,volume*100))])}else{send("setTitle",context,["title":"\(name)\n\(status)","target":0])}
  }
 }
}
#if !TESTING
@main struct PluginMain { static func main() { let plugin=Plugin();plugin.start();RunLoop.main.run() } }
#endif
