//
//  Message.swift
//  Message
//
//  Created by panghu on 7/5/20.
//

import NIO
import NIOHTTP1

public struct Message {
    public let request: MessageRequest
    public let response: MessageResponse
}

public struct MessageUri {
    public let path: String
    public let query: String
    
    init(head: HTTPRequestHead) {
        let uri: [Character] = [Character](head.uri)
        var path: [Character] = []
        var query: [Character] = uri
        for item in uri {
            query.removeFirst()
            guard item != "?" else { break }
            path.append(item)
        }
        self.path = String(path)
        self.query = String(query)
    }
}

public struct MessageRequest {
    
    public let head: HTTPRequestHead
    public let uri: MessageUri
    public let body: MessageBody
    
    public init(head: HTTPRequestHead, stream: MessageByteStream) {
        self.head = head
        self.uri = MessageUri(head: head)
        self.body = MessageBody(stream: stream)
    }
    
    public init(head: HTTPRequestHead, body: MessageBody = MessageBody()) {
        self.head = head
        self.uri = MessageUri(head: head)
        self.body = body
    }
}

public struct MessageResponse {

    public let head: HTTPResponseHead
    public let body: MessageBody
    
    public init(head: HTTPResponseHead, stream: MessageByteStream) {
        self.head = head
        self.body = MessageBody(stream: stream)
    }
    
    public init(head: HTTPResponseHead, body: MessageBody = MessageBody()) {
        self.head = head
        self.body = body
    }
}

public typealias MessageHandler = (_ request: MessageRequest, _ channel: Channel) -> EventLoopFuture<MessageResponse>

public protocol MessageDelegate {
    init()
    func respond(from request: MessageRequest, on channel: Channel) -> EventLoopFuture<MessageResponse>
}

public let messageBody404String: String = "Not Found 404."

public let messageBody404Json: [String : Any] = [
    "data": "null",
    "code": 404
    ]

public let messageBody404HTML: String = """
<!DOCTYPE html>
<html lang=en>
<meta charset=utf-8>
<title>Error 404 (Not Found)!!</title>
<p><b>404.</b> <ins>That’s an error.</ins>
<p>The requested URL <code>/404</code> was not found on this server.
</html>
"""

func MessageRespond(from request: MessageRequest, on channel: Channel) -> EventLoopFuture<MessageResponse> {
    let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
    let response = MessageResponse(head: .init(version: .init(major: 2, minor: 0), status: .notFound), body: MessageBody(string: messageBody404HTML))
    promise.succeed(response)
    return promise.futureResult
}
