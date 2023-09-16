//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by 胖孩 on 10/8/22.
//

import SafariServices
import os.log
import Objective_LevelDB
let SFExtensionMessageKey = "message"

struct MessageData:Decodable{
    // storage.set and get
    let key: String?
    let value: String?
}

struct ExtensionMessage:Decodable{
    let source:String
    let type:Int
    let id:String
    let data: MessageData?
}

public class DB  {
    /* Shared Instance */
    static let store = DB()
    
    let ldb:LevelDB
    init() {
        self.ldb = LevelDB.databaseInLibrary(withName: "db") as! LevelDB
    }
    
    func delete(key: String){
        self.ldb.removeObject(forKey: key)
    }
    
    func put(key:String, value: String){
        self.ldb.setObject(value, forKey: key)
    }
    
    func get(key:String)->String{
        let value =  self.ldb.object(forKey: key)
        return value as! String
    }
    func compact(){
        self.ldb.compact()
    }
}

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems[0] as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey],
              let data = try? JSONSerialization.data(withJSONObject: message, options: []) else { return }
        os_log(.default, "Received message from browser.runtime.sendNativeMessage: %@", message as! CVarArg)

        let response = NSExtensionItem()

        let jsonDecoder = JSONDecoder()
        var respData: [String: Any] = ["source":"VideoTogether"]
        var respType: Int = -1
        if let msg = try? jsonDecoder.decode(ExtensionMessage.self, from: data) {
            if msg.source != "VideoTogether" {
                return;
            }
            respData["id"] = msg.id
            switch(msg.type){
            case 3001:
                DB.store.put(key: msg.data!.key!, value: msg.data!.value!)
                respType = 3002
                break;
            case 3003:
                let value = DB.store.get(key: msg.data!.key!)
                respData["value"] = value
                respType = 3004
                break;
            case 3005:
                DB.store.delete(key: msg.data!.key!)
                respType = 3006
                break;
            case 3007:
                func calculateDiskUsage() -> UInt64 {
                    let fileManager = FileManager.default
                    guard let documentsURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("db") else { return 0 }
                    
                    do {
                        let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [])
                        
                        var totalSize: UInt64 = 0
                        for fileURL in fileURLs {
                            do {
                                let fileAttributes = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                                if let fileSize = fileAttributes.fileSize {
                                    totalSize += UInt64(fileSize)
                                }
                            } catch {
                                // Handle error
                            }
                        }
                        
                        return totalSize
                    } catch {
                        // Handle error
                        return 0
                    }
                }
                let size = calculateDiskUsage()
                respType = 3008
                respData["usage"] = size
                break;
            case 3009:
                DB.store.compact()
                break;
            default:
                break;
            }
        }
        
        respData["type"] = respType
        
        
        response.userInfo = [ SFExtensionMessageKey:respData]

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

}
