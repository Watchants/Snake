//
//  File.swift
//  
//
//  Created by panghu on 9/1/20.
//

import Foundation
import Snake

internal let UploadUrls = URLS(
    suburls: [
    ],
    delegators: [
        .delegate(path: "file", delegate: FileExample.self),
    ],
    handlers: [
    ]) { request, channel in
    
    let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
    let response = MessageResponse(head: .init(version: .init(major: 2, minor: 0), status: .notFound), body: MessageBody(string: messageBody404HTML))
    promise.succeed(response)
    return promise.futureResult
}

struct FileExample : MessageDelegate {
    
    func respond(from request: MessageRequest, on channel: Channel) -> EventLoopFuture<MessageResponse> {
        let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
        var head = HTTPResponseHead(version: .init(major: 2, minor: 0), status: .ok)
        head.headers.add(name: "Content-Type", value: "applicatioon/json")
        let body = MessageBody(json: [
            "code": 200,
            "method": "File",
            "message": "success"
        ])
        let file = FileHandle(forWritingAtPath: "/tmp/file.zip")
        let response = MessageResponse(head: head, body: body)
        request.body.stream?.read { _, element in
            switch element {
            case .bytes(var buffer):
                if let data = buffer.readData(length: buffer.readableBytes) {
                    file?.write(data)
                }
            case .error(let error):
                promise.fail(error)
            case .end(_):
                promise.succeed(response)
            }
        }
        return promise.futureResult
    }
}

