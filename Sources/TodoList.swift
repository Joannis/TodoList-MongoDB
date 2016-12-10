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
import MongoKitten
import LoggerAPI

#if os(Linux)
    typealias Valuetype = Any
#else
    typealias Valuetype = AnyObject
#endif


public class TodoList: TodoListAPI {

    static let defaultMongoHost = "127.0.0.1"
    static let defaultMongoPort = UInt16(27017)
    static let defaultDatabaseName = "todolist"
    static let defaultUsername = "username"
    static let defaultPassword = "password"

    let databaseName = TodoList.defaultDatabaseName

    let collection = "todos"

    let server: Server!

    // Find database if it is already running
    public init(_ dbConfiguration: DatabaseConfiguration) {

        var authorization: MongoCredentials? = nil
        guard let host = dbConfiguration.host,
              let port = dbConfiguration.port else {

                    Log.info("Host and port were not provided")
                    exit(1)
        }
        if let username = dbConfiguration.username, let password = dbConfiguration.password {
               authorization = MongoCredentials(username: username, password: password, database: "admin")
        }

        do {
            server = try Server(ClientSettings(host: MongoHost(hostname: host, port: port), sslSettings: false, credentials: authorization))
        } catch {
            Log.info("MongoDB is not available on host: \(host) and port: \(port)")
            exit(1)
        }
    }

    public init(database: String = TodoList.defaultDatabaseName, host: String = TodoList.defaultMongoHost, port: UInt16 = TodoList.defaultMongoPort,
        username: String = defaultUsername, password: String = defaultPassword) {

         do {
            server = try Server(mongoURL: "mongodb://\(username):\(password)@\(host):\(port)")

         } catch {
             Log.info("MongoDB is not available on the given host: \(host) and port: \(port)")
             exit(1)

         }
     }

    public func count(withUserID: String?, oncompletion: @escaping (Int?, Error?) -> Void) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let query: Query = "userID" == withUserID ?? "default"

            let count = try todosCollection.count(matching: query)

            oncompletion(count, nil)

        } catch {
            oncompletion(nil, error)

        }
    }

    public func clearAll(oncompletion: @escaping (Error?) -> Void) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let query: Query = "type" == "todo"

            try todosCollection.remove(matching: query)

            oncompletion(nil)

        } catch {
            oncompletion(error)

        }
    }

    public func clear(withUserID: String?, oncompletion: @escaping (Error?) -> Void) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let query: Query = "userID" == withUserID ?? "default"

            try todosCollection.remove(matching: query)

            oncompletion(nil)

        } catch {
            oncompletion(error)

        }
    }

    public func get(oncompletion: @escaping ([TodoItem]?, Error?) -> Void ) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let items = try todosCollection.find()

            let todoItems = try parseTodoItemList(items)

            oncompletion(todoItems, nil)

        } catch {
            oncompletion(nil, error)

        }

    }

    public func get(withUserID: String?, oncompletion: @escaping ([TodoItem]?, Error?) -> Void) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let query: Query = "userID" == withUserID ?? "default"

            let items = try todosCollection.find(matching: query)

            let todoItems = try parseTodoItemList(items)

            oncompletion(todoItems, nil)

        } catch {
            oncompletion(nil, error)

        }

    }

    public func get(withUserID: String?, withDocumentID: String, oncompletion: @escaping (TodoItem?, Error?) -> Void ) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let id = try ObjectId(withDocumentID)

            let query: Query = withUserID != nil ? "userID" == withUserID! && "_id" == id :
                                                   "userID" == "default" && "_id" == id

            let item = try todosCollection.findOne(matching: query)

            guard let sid = item?["_id"] as String?,
                  let suid = item?["userID"] as String?,
                  let stitle = item?["title"] as String?,
                  let srank = item?["rank"] as Int?,
                  let scompleted = item?["completed"] as Bool? else {

                   oncompletion(nil, TodoCollectionError.ParseError)
                   return
               }

            let todoItem = TodoItem(documentID: sid, userID: suid, rank: srank, title: stitle, completed: scompleted)

            oncompletion(todoItem, nil)

        } catch {
            oncompletion(nil, error)

        }

    }

    public func add(userID: String?, title: String, rank: Int, completed: Bool,
        oncompletion: @escaping (TodoItem?, Error?) -> Void ) {

        let uid = userID ?? "default"

        let todoItem: Document = [
                                    "type": "todo",
                                    "userID": uid,
                                    "title": title,
                                    "rank": rank,
                                    "completed": completed
        ]

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let id = try todosCollection.insert(todoItem).string

            let todoItem = TodoItem(documentID: id ?? "", userID: userID, rank: rank, title: title, completed: completed)

            oncompletion(todoItem, nil)

        } catch {
            oncompletion(nil, error)

        }

    }

    public func update(documentID: String, userID: String?, title: String?, rank: Int?,
        completed: Bool?, oncompletion: @escaping (TodoItem?, Error?) -> Void ) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let id = try ObjectId(documentID)

            let uid = userID ?? "default"

            let item = try todosCollection.findOne(matching: ["_id": id, "userID": uid])

            guard let object = item else {
                oncompletion(nil, TodoCollectionError.ParseError)
                return
            }

            let updatedTodo: Document = [
                               "type": "todo",
                               "userID": userID != nil ? userID! : object["userID"] as String? ?? "",
                               "title": title != nil ? title! : object["title"] as String? ?? "",
                               "rank": rank != nil ? rank! : object["rank"] as Int!,
                               "completed": completed != nil ? completed! : object["completed"] as Bool? ?? false
            ]

            try todosCollection.update(matching: "_id" == id, to: updatedTodo)

            let todoItem = TodoItem(documentID: documentID,
                                        userID: updatedTodo["userID"] as String?,
                                         rank: updatedTodo["rank"] as Int? ?? 0,
                                         title: updatedTodo["title"] as String? ?? "",
                                     completed: updatedTodo["completed"] as Bool? ?? false)

            oncompletion(todoItem, nil)


        } catch {
            oncompletion(nil, error)

        }
    }

    public func delete(withUserID: String?, withDocumentID: String, oncompletion: @escaping (Error?) -> Void) {

        do {
            let database = server[databaseName]
            let todosCollection = database[collection]

            let id = try ObjectId(withDocumentID)

            let uid = withUserID ?? "default"

            try todosCollection.remove(matching: "_id" == id && "userID" == uid)

            oncompletion(nil)

        } catch {
            print(error)
            oncompletion(error)

        }

    }

    public func parseTodoItemList(_ document: Cursor<Document>) throws -> [TodoItem] {

        let todos: [TodoItem] = Array(document).flatMap {
            doc in

            let id = doc["_id"] as String?
            let userID = doc["userID"] as String?
            let title = doc["title"] as String?
            let completed = doc["completed"] as Bool?
            let rank = doc["rank"] as Int?

            return TodoItem(documentID: id ?? "", userID: userID, rank: rank ?? 0, title: title ?? "", completed: completed ?? false)

        }

        return todos
    }

}
