//
//  File.swift
//  
//
//  Created by panghu on 9/1/20.
//

import Foundation

public final class MessageByteStream {
        
    private var ended: Bool
    private var buffer: [Element]
    private var handler: ((MessageByteStream, Element) -> Void)?
    
    public init() {
        self.buffer = []
        self.ended = false
        self.handler = nil
    }
}

extension MessageByteStream {
    
    public enum Element {
        case bytes(ByteBuffer)
        case error(Error)
        case end(HTTPHeaders?)
    }
    
    public func read(_ handler: @escaping (MessageByteStream, Element) -> Void) {
        guard self.handler == nil else { return }
        for element in self.buffer {
            handler(self, element)
        }
        self.buffer = []
        self.handler = handler
    }
    
    public func write(_ element: Element) {
        guard !ended else { return }
        
        if let handler = handler {
            handler(self, element)
        } else {
            buffer.append(element)
        }
        if case .end = element {
            ended = true
        } else if case .error(_) = element {
            ended = true
        }
    }
    
    public func consume(on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        let promise = eventLoop.makePromise(of: ByteBuffer.self)
        var data = ByteBufferAllocator().buffer(capacity: 0)
        read { stream, element in
            switch element {
            case .bytes(var byteBuffer):
                data.writeBuffer(&byteBuffer)
            case .error(let error):
                promise.fail(error)
            case .end(_):
                promise.succeed(data)
            }
        }
        return promise.futureResult
    }
}
