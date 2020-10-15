//
//  main.swift
//  Example
//
//  Created by panghu on 7/5/20.
//

import Snake

struct GetExample : MessageDelegate {
    
    func respond(from request: MessageRequest, on channel: Channel) -> EventLoopFuture<MessageResponse> {
        let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
        let head = HTTPResponseHead(version: .init(major: 2, minor: 0), status: .ok)
        let body = MessageBody(json: [
            "code": 200,
            "method": "GET",
            "message": "success"
        ])
        let response = MessageResponse(head: head, body: body)
        promise.succeed(response)
        return promise.futureResult
    }
}

struct PostExample : MessageDelegate {
    
    func respond(from request: MessageRequest, on channel: Channel) -> EventLoopFuture<MessageResponse> {
        let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
        let head = HTTPResponseHead(version: .init(major: 2, minor: 0), status: .ok)
        let body = MessageBody(json: [
            "code": 200,
            "method": "POST",
            "message": "success"
        ])
        let response = MessageResponse(head: head, body: body)
        promise.succeed(response)
        return promise.futureResult
    }
}

let urls = URLS(
    suburls: [
        .url(path: "api/user", include: URLS()),
        .url(path: "api/upload", include: UploadUrls)
    ],
    delegators: [
        .delegate(path: "get", delegate: GetExample.self),
        .delegate(path: "post", delegate: PostExample.self)
    ],
    handlers: [
        .handler(path: "delete") { request, channel -> EventLoopFuture<MessageResponse> in
            let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
            let head = HTTPResponseHead(version: .init(major: 2, minor: 0), status: .ok)
            let body = MessageBody(json: [
                "code": 200,
                "method": "DELETE",
                "message": "success"
            ])
            let response = MessageResponse(head: head, body: body)
            promise.succeed(response)
            return promise.futureResult
        },
        .handler(path: "head") { request, channel -> EventLoopFuture<MessageResponse> in
            let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
            let head = HTTPResponseHead(version: .init(major: 2, minor: 0), status: .ok)
            let body = MessageBody(json: [
                "code": 200,
                "method": "HEAD",
                "message": "success"
            ])
            let response = MessageResponse(head: head, body: body)
            promise.succeed(response)
            return promise.futureResult
        }
    ]) { request, channel in
    
    let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
    let response = MessageResponse(head: .init(version: .init(major: 2, minor: 0), status: .notFound), body: MessageBody(string: messageBody404HTML))
    promise.succeed(response)
    return promise.futureResult
}

let app = Application(
    configuration: .init(host: "127.0.0.1", port: 8889),
    eventLoopGroup: .init(numberOfThreads: System.coreCount),
    urls: urls
)

try app.start().wait()

guard let address = app.localAddress else {
    fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
}

let host: String
let `protocol`: String
switch address {
case .v4(let ip):
    host = ip.host + (address.port.map { ":\($0)" } ?? "")
    `protocol` = "IPv4"
case .v6(let ip):
    host = ip.host + (address.port.map { ":\($0)" } ?? "")
    `protocol` = "IPv6"
default: fatalError("??")
}

print("Server started and listening on [\(`protocol`)] http://\(host), logger path \(app.configuration.logger)")

try app.onClose.wait()
