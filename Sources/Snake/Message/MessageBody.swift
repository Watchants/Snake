//
//  File.swift
//
//
//  Created by panghu on 8/31/20.
//

import Foundation

public struct MessageBody {

public let storage: MessageBody.Storage

    public init() {
        storage = .empty
    }

    public init(buffer: ByteBuffer) {
        storage = .buffer(buffer)
    }

    public init(data: Data) {
        storage = .data(data)
    }

    public init(string: String) {
        storage = .string(string)
    }

    public init(json: Any) {
        storage = .json(json)
    }

    public init(stream: MessageByteStream) {
        storage = .stream(stream)
    }
}

extension MessageBody {

    public var count: Int? {
        switch storage {
        case .empty:
            return 0
        case .buffer(let buffer):
            return buffer.readableBytes
        case .data(let data):
            return data.count
        case .string(let string):
            return string.utf8.count
        case .json(_):
            return nil
        case .stream(_):
            return nil
        }
    }

    public var buffer: ByteBuffer? {
        switch storage {
        case .empty:
            return ByteBuffer()
        case .buffer(let buffer):
            return buffer
        case .data(let data):
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            return buffer
        case .string(let string):
            var buffer = ByteBufferAllocator().buffer(capacity: string.count)
            buffer.writeString(string)
            return buffer
        case .json(let json):
            guard let data = try? JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed) else {
                return nil
            }
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            return buffer
        case .stream(_):
            return nil
        }
    }

    public var data: Data? {
        switch storage {
        case .empty:
            return Data()
        case .buffer(var buffer):
            return buffer.readData(length: buffer.readableBytes)
        case .data(let data):
            return data
        case .string(let string):
            return Data(string.utf8)
        case .json(let json):
            return try? JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
        case .stream(_):
            return nil
        }
    }

    public var string: String? {
        switch storage {
        case .empty:
            return ""
        case .buffer(var buffer):
            return buffer.readString(length: buffer.readableBytes)
        case .data(let data):
            return String(data: data, encoding: .utf8)
        case .string(let string):
            return string
        case .json(let json):
            guard let data = try? JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        case .stream(_):
            return nil
        }
    }

    public var json: Any? {
        switch storage {
        case .empty:
            return [:]
        case .buffer(var buffer):
            guard let data = buffer.readData(length: buffer.readableBytes) else {
                return nil
            }
            return try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        case .data(let data):
            return try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        case .string(let string):
            guard let data = string.data(using: .utf8) else {
                return nil
            }
            return try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        case .json(let json):
            return json
        case .stream(_):
            return nil
        }
    }

    public var stream: MessageByteStream? {
        switch storage {
        case .stream(let stream):
            return stream
        default:
            return nil
        }
    }
}

extension MessageBody {

    public func buffer(on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        switch storage {
        case .empty:
            let promise = eventLoop.makePromise(of: ByteBuffer.self)
            promise.succeed(ByteBuffer())
            return promise.futureResult
        case .buffer(let buffer):
            let promise = eventLoop.makePromise(of: ByteBuffer.self)
            promise.succeed(buffer)
            return promise.futureResult
        case .data(let data):
            let promise = eventLoop.makePromise(of: ByteBuffer.self)
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            promise.succeed(buffer)
            return promise.futureResult
        case .string(let string):
            let promise = eventLoop.makePromise(of: ByteBuffer.self)
            var buffer = ByteBufferAllocator().buffer(capacity: string.count)
            buffer.writeString(string)
            promise.succeed(buffer)
            return promise.futureResult
        case .json(let json):
            let promise = eventLoop.makePromise(of: ByteBuffer.self)
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
                var buffer = ByteBufferAllocator().buffer(capacity: data.count)
                buffer.writeBytes(data)
                promise.succeed(buffer)
            } catch {
                promise.fail(error)
            }
            return promise.futureResult
        case .stream(let stream):
            return stream.consume(on: eventLoop)
        }
    }

    public func data(on eventLoop: EventLoop) -> EventLoopFuture<Data> {
        let promise = eventLoop.makePromise(of: Data.self)
        switch storage {
        case .empty:
            promise.succeed(Data())
        case .buffer(var buffer):
            let data = buffer.readData(length: buffer.readableBytes) ?? Data()
            promise.succeed(data)
        case .data(let data):
            promise.succeed(data)
        case .string(let string):
            let data = Data(string.utf8)
            promise.succeed(data)
        case .json(let json):
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
                promise.succeed(data)
            } catch {
                promise.fail(error)
            }
        case .stream(let stream):
            stream.consume(on: eventLoop).whenComplete { result in
                switch result {
                case .success(var buffer):
                    let data = buffer.readData(length: buffer.readableBytes) ?? Data()
                    promise.succeed(data)
                case .failure(let error):
                    promise.fail(error)
                }
            }
        }
        return promise.futureResult
    }

    public func string(on eventLoop: EventLoop) -> EventLoopFuture<String> {
        let promise = eventLoop.makePromise(of: String.self)
        switch storage {
        case .empty:
            promise.succeed("")
        case .buffer(var buffer):
            if let string = buffer.readString(length: buffer.readableBytes) {
                promise.succeed(string)
            } else {
                promise.fail(MBError(.bufferException))
            }
        case .data(let data):
            if let string = String(data: data, encoding: .utf8) {
                promise.succeed(string)
            } else {
                promise.fail(MBError(.dataException))
            }
        case .string(let string):
            promise.succeed(string)
        case .json(let json):
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
                if let string = String(data: data, encoding: .utf8) {
                    promise.succeed(string)
                } else {
                    promise.fail(MBError(.jsonException))
                }
            } catch {
                promise.fail(error)
            }
        case .stream(let stream):
            stream.consume(on: eventLoop).whenComplete { result in
                switch result {
                case .success(var buffer):
                    if let string = buffer.readString(length: buffer.readableBytes) {
                        promise.succeed(string)
                    } else {
                        promise.fail(MBError(.streamException))
                    }
                case .failure(let error):
                    promise.fail(error)
                }
            }
        }
        return promise.futureResult
    }

    public func json(on eventLoop: EventLoop) -> EventLoopFuture<Any> {
        let promise = eventLoop.makePromise(of: Any.self)
        switch storage {
        case .empty:
            promise.succeed([:])
        case .buffer(var buffer):
            do {
                if let data = buffer.readData(length: buffer.readableBytes) {
                    let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    promise.succeed(json)
                } else {
                    promise.fail(MBError(.bufferException))
                }
            } catch {
                promise.fail(error)
            }
        case .data(let data):
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                promise.succeed(json)
            } catch {
                promise.fail(error)
            }
        case .string(let string):
            do {
                if let data = string.data(using: .utf8) {
                    let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    promise.succeed(json)
                } else {
                    promise.fail(MBError(.stringException))
                }
            } catch {
                promise.fail(error)
            }
        case .json(let json):
            promise.succeed(json)
        case .stream(let stream):
            stream.consume(on: eventLoop).whenComplete { result in
                switch result {
                case .success(var buffer):
                    do {
                        if let data = buffer.readData(length: buffer.readableBytes) {
                            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                            promise.succeed(json)
                        } else {
                            promise.fail(MBError(.streamException))
                        }
                    } catch {
                        promise.fail(error)
                    }
                case .failure(let error):
                    promise.fail(error)
                }
            }
        }
        return promise.futureResult
    }
    
    public func read(_ handler: @escaping (Element) -> Void) {
        switch storage {
        case .empty:
            handler(.end(nil))
        case .buffer(let buffer):
            handler(.bytes(buffer))
            handler(.end(nil))
        case .data(let data):
            var buffer = ByteBufferAllocator().buffer(capacity: data.count)
            buffer.writeBytes(data)
            handler(.bytes(buffer))
            handler(.end(nil))
        case .string(let string):
            var buffer = ByteBufferAllocator().buffer(capacity: string.count)
            buffer.writeString(string)
            handler(.bytes(buffer))
            handler(.end(nil))
        case .json(let json):
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
                var buffer = ByteBufferAllocator().buffer(capacity: data.count)
                buffer.writeBytes(data)
                handler(.bytes(buffer))
                handler(.end(nil))
            } catch {
                handler(.error(error))
            }
        case .stream(let stream):
            stream.read { stream, element in
                switch element {
                case .bytes(let buffer):
                    handler(.bytes(buffer))
                case .error(let error):
                    handler(.error(error))
                case .end(let headers):
                    handler(.end(headers))
                }
            }
        }
    }
}

extension MessageBody {

    public enum Storage {
        case empty
        case buffer(ByteBuffer)
        case data(Data)
        case string(String)
        case json(Any)
        case stream(MessageByteStream)
    }
    
    public enum Element {
        case bytes(ByteBuffer)
        case error(Error)
        case end(HTTPHeaders?)
    }

    public struct MBError: Error {
        public enum Reason {
            case bufferException
            case dataException
            case stringException
            case jsonException
            case streamException
        }
        public let reason: Reason
        public init(_ reason: Reason) { self.reason = reason }
    }
}
