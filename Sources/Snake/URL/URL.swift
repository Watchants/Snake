//
//  URL.swift
//  URL
//
//  Created by panghu on 7/5/20.
//

import NIO

public class URLpatterns {
    
    let urls: URLS
    
    let suburls: [Int: MessageHandler]
    let delegators: [Int: MessageDelegate.Type]
    let handlers: [Int: MessageHandler]
    
    init(urls: URLS) {
        self.urls = urls
        
        var suburls = [([String.SubSequence], MessageHandler)]()
        var delegators = [([String.SubSequence], MessageDelegate.Type)]()
        var handlers = [([String.SubSequence], MessageHandler)]()
        urls.elements(paths: [], suburls: &suburls, delegators: &delegators, handlers: &handlers)
        
        self.suburls = suburls.reduce([:]) { (result, item) -> [Int: MessageHandler] in
            let hashValue = URLS.SubpathsHashValue(subpaths: item.0)
            var dict = result
            dict[hashValue] = item.1
            return dict
        }
        self.delegators = delegators.reduce([:]) { (result, item) -> [Int: MessageDelegate.Type] in
            let hashValue = URLS.SubpathsHashValue(subpaths: item.0)
            var dict = result
            dict[hashValue] = item.1
            return dict
        }
        self.handlers = handlers.reduce([:]) { (result, item) -> [Int: MessageHandler] in
            let hashValue = URLS.SubpathsHashValue(subpaths: item.0)
            var dict = result
            dict[hashValue] = item.1
            return dict
        }
    }
    
    func respond(path: String) -> MessageHandler {
        let subpaths = URLS.Subpaths(path: path)
        let hashValue = URLS.SubpathsHashValue(subpaths: subpaths)
        if let delegator = delegators[hashValue] {
            return delegator.init().respond(from:on:)
        }
        if let suburl = suburls[hashValue] {
            return suburl
        }
        if let handler = handlers[hashValue] {
            return handler
        }

        var next = subpaths
        while true {
            let hashValue = URLS.SubpathsHashValue(subpaths: next)
            if let suburl = suburls[hashValue] {
                return suburl
            }
            if next.count <= 0 {
                break
            }
            next.removeLast()
        }
        return MessageRespond(from:on:)
    }
}

open class URLS: URLSCodable, MessageDelegate {
    
    // MARK: URLSCodable
    
    public let subpaths: [String.SubSequence]
    
    public var element: MessageHandler {
        return reveal ?? respond(from:on:)
    }
    
    // MARK: URLCollection
    
    private let suburls: [URL]

    private let delegators: [Delegator]

    private let handlers: [Handler]
    
    private let reveal: MessageHandler?
    
    public required init() {
        self.reveal = nil
        self.subpaths = []
        self.suburls = []
        self.delegators = []
        self.handlers = []
    }
    
    public required init(suburls: [URL] = [], delegators: [Delegator] = [], handlers: [Handler] = [], _ reveal : MessageHandler? = nil) {
        self.subpaths = []
        self.reveal = reveal
        self.suburls = suburls
        self.delegators = delegators
        self.handlers = handlers
    }
    
    internal func elements(paths: [String.SubSequence],
                           suburls: inout [([String.SubSequence], MessageHandler)],
                           delegators: inout [([String.SubSequence], MessageDelegate.Type)],
                           handlers: inout [([String.SubSequence], MessageHandler)]) {
        for item in self.handlers {
            handlers.append((paths + item.subpaths, item.element))
        }
        for item in self.delegators {
            delegators.append((paths + item.subpaths, item.element))
        }
        suburls.append((paths, element))
        for item in self.suburls {
            suburls.append((paths + item.subpaths, item.element.element))
            item.element.elements(paths: paths + item.subpaths, suburls: &suburls, delegators: &delegators, handlers: &handlers)
        }
    }
    
    open func respond(from request: MessageRequest, on channel: Channel) -> EventLoopFuture<MessageResponse> {
        let promise = channel.eventLoop.makePromise(of: MessageResponse.self)
        let response = MessageResponse(head: .init(version: .init(major: 2, minor: 0), status: .notFound), body: MessageBody(string: messageBody404HTML))
        promise.succeed(response)
        return promise.futureResult
    }
}

extension URLS {
    
    public class URL: URLSCodable {
        
        public let subpaths: [String.SubSequence]
        
        public let element: URLS
        
        private init(path: String, element: URLS) {
            self.subpaths = Self.Subpaths(path: path)
            self.element = element
        }

        internal init(subpaths: [String.SubSequence], element: URLS) {
            self.subpaths = subpaths
            self.element = element
        }
        
        public static func url(path: String, include: URLS) -> URL {
            return .init(path: path, element: include)
        }
    }
    
    public class Delegator: URLSCodable {
        
        public let subpaths: [String.SubSequence]
        
        public let element: MessageDelegate.Type
        
        private init(path: String, element: MessageDelegate.Type) {
            self.subpaths = Self.Subpaths(path: path)
            self.element = element
        }
        
        internal init(subpaths: [String.SubSequence], element: MessageDelegate.Type) {
            self.subpaths = subpaths
            self.element = element
        }
        
        public static func delegate(path: String, delegate: MessageDelegate.Type) -> Delegator {
            return .init(path: path, element: delegate)
        }
    }
    
    public class Handler: URLSCodable {
        
        public let subpaths: [String.SubSequence]
        
        public let element: MessageHandler
        
        private init(path: String, element: @escaping MessageHandler) {
            self.subpaths = Self.Subpaths(path: path)
            self.element = element
        }
        
        internal init(subpaths: [String.SubSequence], element: @escaping MessageHandler) {
            self.subpaths = subpaths
            self.element = element
        }
        
        public static func handler(path: String, _ handler: @escaping MessageHandler) -> Handler {
            return .init(path: path, element: handler)
        }
    }
}

public protocol URLSCodable {
    
    associatedtype Element

    var subpaths: [String.SubSequence] { get }
    
    var element: Element { get }

}

extension URLSCodable {

    internal static func Subpaths(path: String) -> [String.SubSequence] {
        return path.split(separator: "/").filter { $0.count > 0 }
    }

    internal static func SubpathsHashValue(subpaths: [String.SubSequence]) -> Int {
        return subpaths.joined(separator: "/").hash
    }
}
