/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

 import Foundation
 import Kitura
 import HeliumLogger
 import LoggerAPI
 import CloudFoundryEnv

import SwiftyJSON

 Log.logger = HeliumLogger()

 extension DatabaseConfiguration {

     init(with service: Service) {

         if let credentials = service.credentials {
            print("creds: \(service.credentials)")
            if credentials["port"].string == nil, let neededURL = credentials["uri"].stringValue.components(separatedBy: ",").first,
                let url = URL(string: neededURL), let port = url.port {
                self.uri = url
                self.host = url.host
                self.username = url.user
                self.password = url.password
                self.port = UInt16(port)
             } else {
                 self.uri = nil
                 self.host = credentials["uri"].stringValue
                 self.username = credentials["user"].stringValue
                 self.password = credentials["password"].stringValue
                 self.port = UInt16(credentials["port"].stringValue)
             }
         } else {
             self.uri = nil
             self.host = "127.0.0.1"
             self.username = nil
             self.password = nil
             self.port = UInt16(27017)
         }
         self.options = [String : AnyObject]()
     }
 }

 let databaseConfiguration: DatabaseConfiguration
 let todos: TodoList

 do {
    if let service = try CloudFoundryEnv.getAppEnv().getService(spec: "TodoList-MongoDB") {
//        let uri = "mongodb://admin:QMJVELKIYGOKIGKB@bluemix-sandbox-dal-9-portal.5.dblayer.com:19889,bluemix-sandbox-dal-9-portal.4.dblayer.com:19889/admin?ssl=true"
//        let service = Service(name: "", label: "", plan: "", tags: [""], credentials: JSON(["uri": value]))
         databaseConfiguration = DatabaseConfiguration(with: service)
         if let dbURL = databaseConfiguration.uri {
             todos = TodoList(databaseURL: dbURL)
         } else {
             todos = TodoList(databaseConfiguration)
         }
     } else {
         todos = TodoList()
     }

     let controller = TodoListController(backend: todos)

     let port = try CloudFoundryEnv.getAppEnv().port

     Kitura.addHTTPServer(onPort: port, with: controller.router)
     Kitura.run()

 } catch CloudFoundryEnvError.InvalidValue {
     Log.error("Oops... something went wrong. Server did not start!")
 }
