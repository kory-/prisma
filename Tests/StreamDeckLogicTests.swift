import Foundation
let p=Plugin();var messages:[[String:Any]]=[];var commands:[URL]=[]
p.messageSink={messages.append($0)};p.commandSink={commands.append($0)};p.active=true;p.lastState=Date()
p.slots=["alpha.app","beta.app","",""];p.levels=["alpha.app":["name":"Alpha","volume":0.5,"running":true],"beta.app":["name":"Beta","volume":0.8,"running":true]]
func event(_ e:String,_ c:String,_ col:Int,_ settings:[String:Any]=[:],_ extra:[String:Any]=[:])->[String:Any]{var payload:[String:Any]=["controller":"Encoder","coordinates":["column":col,"row":0],"settings":settings];for(k,v)in extra{payload[k]=v};return ["event":e,"context":c,"action":"io.github.kory-.prisma.auto","payload":payload]}
p.receive(event("willAppear","dial1",0));p.receive(event("willAppear","dial2",1));assert(p.displayed["dial1"]=="alpha.app" && p.displayed["dial2"]=="beta.app")
p.receive(event("dialRotate","dial1",0,[:],["ticks":-2]));let q=URLComponents(url:commands.last!,resolvingAgainstBaseURL:false)!.queryItems!;assert(q.contains{ $0.name=="app"&&$0.value=="alpha.app" });assert(q.contains{ $0.name=="op"&&$0.value=="down" });assert(q.contains{ $0.name=="step"&&$0.value=="10.0" })
p.slots=["beta.app","alpha.app","",""];p.refresh();assert(p.displayed["dial1"]=="alpha.app")
p.receive(event("dialDown","dial1",0));assert(commands.last!.absoluteString.contains("op=mute"));assert(commands.last!.absoluteString.contains("app=alpha.app"))
p.locks["dial1"]=Date.distantPast;p.refresh();assert(p.displayed["dial1"]=="beta.app")
p.receive(event("willAppear","dial3",2));let count=commands.count;p.receive(event("dialRotate","dial3",2,[:],["ticks":1]));assert(commands.count==count);assert(messages.last?["event"] as? String == "showAlert")
let feedback=messages.filter{$0["event"]as?String=="setFeedback"}.last!["payload"]as![String:Any];assert(feedback["icon"] != nil)
p.levels["beta.app"]?["volume"]=0.299999828338623;p.refresh()
let rounded=messages.last{$0["event"]as?String=="setFeedback" && $0["context"]as?String=="dial1"}!["payload"]as![String:Any];assert(rounded["value"]as?String=="30%")
print("PASS: percentage rounding,  four-slot targeting, icon feedback, signed dial ticks, displayed-target lock, mute target, empty-slot guard")

let tabKey="chrome-tab:session:7", tabIcon="data:image/png;base64,iVBORw0KGgo="
p.levels[tabKey] = ["name":"Example tab","volume":0.4,"running":true,"kind":"tab","icon":tabIcon]
p.slots=[tabKey,"","",""];p.locks.removeAll();p.refresh()
assert(p.displayed["dial1"]==tabKey);assert(p.icon(tabKey)==tabIcon)
p.receive(event("dialRotate","dial1",0,[:],["ticks":-1]))
assert(URLComponents(url:commands.last!,resolvingAgainstBaseURL:false)!.queryItems!.contains{$0.name=="app" && $0.value==tabKey})
print("PASS: tab favicon feedback and exact tab target for Stream Deck")

let resourceURL = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("io.github.kory-.prisma.sdPlugin")
for (locale, expected) in [("ja", "再生待ち"), ("ja_JP", "再生待ち"), ("en-GB", "Waiting for audio"), ("fr", "Waiting for audio")] {
 p.configureLanguage(info:["application":["language":locale]], resources:resourceURL)
 p.active=true; p.lastState=Date(); p.slots=["", "", "", ""]; p.locks.removeAll(); p.refresh()
 let payload=messages.last{$0["event"] as? String == "setFeedback" && $0["context"] as? String == "dial1"}!["payload"] as! [String:Any]
 assert(payload["value"] as? String == expected)
}
print("PASS: Stream Deck language negotiation and localized dial feedback")
