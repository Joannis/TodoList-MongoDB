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
import TodoListAPI
import MongoKitten


#if os(Linux)
    typealias Valuetype = Any
#else
    typealias Valuetype = AnyObject
#endif

enum Errors: ErrorProtocol {
    case couldNotRetrieveData
    case objectDoesNotExist
    case couldNotUpdate
    case couldNotAddItem
    case couldNotParseData
}
/// TodoList for MongoDB
public class TodoList: TodoListAPI {

    static let defaultMongoHost = "127.0.0.1"
    static let defaultMongoPort = UInt16(5984)
    static let defaultDatabaseName = "todolist"

    let databaseName = "todolist"

    let designName = "tododb"

    let server: Server!

    let collection = "todos"

    // Find database if it is already running
    /*public init(_ dbConfiguration: DatabaseConfiguration) {

        connectionProperties = ConnectionProperties(host: dbConfiguration.host!,
                                                    port: Int16(dbConfiguration.port!),
                                                    secured: true,
                                                    username: dbConfiguration.username,
                                                    password: dbConfiguration.password)

    }*/

    public init(database: String = TodoList.defaultDatabaseName, host: String = TodoList.defaultMongoHost,
                port: UInt16 = TodoList.defaultMongoPort,
                username: String? = nil, password: String? = nil) {

                do {

                    server = try Server("mongodb://username:password@localhost:27017", automatically: true)

                } catch {

                    print("MongoDB is not available on the given host and port")
                    exit(1)

                }

                //let database = server[databaseName]
                //let todosCollection = database[collection]

    }

    public func count(oncompletion: (Int?, ErrorProtocol?) -> Void) {

        let database = server[databaseName]
        let todosCollection = database[collection]

        do {
            let items = try todosCollection.find()

            var count = 0
            for _ in items {
                count += 1
            }
            oncompletion(count, nil)

        } catch {
            oncompletion(nil, Errors.couldNotRetrieveData)

        }


    }

    public func count(withUserID: String, oncompletion: (Int?, ErrorProtocol?) -> Void) {

        let database = server[databaseName]
        let todosCollection = database[collection]

        do {
            let query: Query = "userID" == withUserID

            let items = try todosCollection.find(matching: query)

            var count = 0
            for _ in items {
                count += 1
            }
            oncompletion(count, nil)

        } catch {
            oncompletion(nil, Errors.couldNotRetrieveData)

        }
    }

    public func clear(oncompletion: (ErrorProtocol?) -> Void) {
        oncompletion(nil)
    }

    public func clear(withUserID: String, oncompletion: (ErrorProtocol?) -> Void) {
        oncompletion(nil)
    }

    public func get(oncompletion: ([TodoItem]?, ErrorProtocol?) -> Void ) {

        let database = server[databaseName]
        let todosCollection = database[collection]

        do {
            let items = try todosCollection.find()

            let todoItems = try parseTodoItemList(items)

            oncompletion(todoItems, nil)

        } catch {
            oncompletion(nil, Errors.couldNotRetrieveData)

        }

    }

    public func get(withUserID: String, oncompletion: ([TodoItem]?, ErrorProtocol?) -> Void) {

        let database = server[databaseName]
        let todosCollection = database[collection]

        do {
            let query: Query = "userID" == withUserID

            let items = try todosCollection.find(matching: query)

            let todoItems = try parseTodoItemList(items)

            oncompletion(todoItems, nil)

        } catch {
            oncompletion(nil, Errors.couldNotRetrieveData)

        }

    }

    public func get(withUserID: String, withDocumentID: String, oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {

        let database = server[databaseName]
        let todosCollection = database[collection]

        do {
            let query: Query = "userID" == withUserID && "objectID" == withDocumentID

            let item = try todosCollection.findOne(matching: query)

            guard let sid = item?["objectID"].string,
                    suid = item?["userID"].string,
                    stitle = item?["title"].string,
                    sorder = item?["order"].int,
                    scompleted = item?["completed"].bool else {
                        return
                    }

            let todoItem = TodoItem(documentID: sid, userID: suid, order: sorder, title: stitle, completed: scompleted)

            oncompletion(todoItem, nil)

        } catch {
            oncompletion(nil, Errors.couldNotRetrieveData)

        }

    }

    public func add(userID: String, title: String, order: Int, completed: Bool,
        oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {

        let todoItem: Document = [
                                    "type": "todo",
                                    "userID": ~userID,
                                    "title": ~title,
                                    "order": ~order,
                                    "completed": ~completed
        ]

        let database = server[databaseName]
        let todosCollection = database[collection]

        do {
            let _ = try todosCollection.insert(todoItem)

            let todoItem = TodoItem(documentID: userID, userID: userID, order: order, title: title, completed: completed) //Error

            oncompletion(todoItem, nil)

        } catch {
            oncompletion(nil, Errors.couldNotAddItem) // TODO: Put in actual errors

        }

    }

    public func update(documentID: String, userID: String?, title: String?, order: Int?,
        completed: Bool?, oncompletion: (TodoItem?, ErrorProtocol?) -> Void ) {

        //let database = server[databaseName]
        //let todosCollection = database[collection]
        oncompletion(nil, Errors.couldNotUpdate)

        /*do {
            let obj = try todosCollection.findOne(matching: ["ObjectID": ~documentID])
            
            if let object = obj {
                let updatedTodo: [String: Valuetype] = [
                                                           "type": "todo",
                                                           "userID": userID != nil ? userID! : object["userID"].string,
                                                           "title": title != nil ? title! : object["title"].string,
                                                           "order": order != nil ? order! : object["order"].int,
                                                           "completed": completed != nil ? completed! : object["completed"].bool
                ]
                
                do {
                    try todosCollection.update(matching: ["objectID": ~documentID], to: updatedTodo)
                    
                    oncompletion(nil, nil) //
                    
                } catch {
                    oncompletion(nil, Errors.couldNotUpdate)
                    
                }
            }

        } catch {
            oncompletion(nil, Errors.objectDoesNotExist)
            
        }*/
    }

    public func delete(withUserID: String, withDocumentID: String, oncompletion: (ErrorProtocol?) -> Void) {

        let database = server[databaseName]
        let todosCollection = database[collection]

        do {
            try todosCollection.remove(matching: ["objectID": ~withDocumentID])

            oncompletion(nil)

        } catch {
            oncompletion(Errors.objectDoesNotExist)

        }

    }

    public func parseGetIDandRev(_ document: [Document]) throws -> [(String, String)] {

        return Array(document).flatMap {

            let doc = $0["doc"]
            let id = doc["objectID"].string
            let rev = doc["_rev"].string

            return (id, rev)

        }

    }

    public func parseTodoItemList(_ document: Cursor<Document>) throws -> [TodoItem] {

        let todos: [TodoItem] = Array(document).flatMap {
            doc in

            let id = doc["objectID"].string
            let userID = doc["userID"].string
            let title = doc["title"].string
            let completed = doc["completed"].bool
            let order = doc["order"].int

            return TodoItem(documentID: id, userID: userID, order: order, title: title, completed: completed)

        }

        return todos
    }

}