//
//  Application.swift
//  Snake
//
//  Created by panghu on 7/5/20.
//

import NIO
import NIOHTTP2

public final class Application {
    
    public let configuration: Configuration
    public let eventLoopGroup: EventLoopGroup
    public let urlPatterns: URLpatterns
    
    private var channel: Channel?
    
    public init(configuration: Configuration, eventLoopGroup: MultiThreadedEventLoopGroup, urls: URLS) {
        self.configuration = configuration
        self.eventLoopGroup = eventLoopGroup
        self.urlPatterns = URLpatterns(urls: urls)
    }
    
    deinit { try? eventLoopGroup.syncShutdownGracefully() }
    
    public var localAddress: SocketAddress? {
        guard let channel = channel else {
            fatalError("Called onClose before start()")
        }
        return channel.localAddress
    }
    
    public var onClose: EventLoopFuture<Void> {
        guard let channel = channel else {
            fatalError("Called onClose before start()")
        }
        return channel.closeFuture
    }
    
    public func start() -> EventLoopFuture<Void> {
        
        let configuration = self.configuration
        let eventLoopGroup = self.eventLoopGroup
        
        let socketBootstrap = ServerBootstrap(group: eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: configuration.backlog)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: configuration.reuseAddr ? 1 : 0)
            
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel -> EventLoopFuture<Void> in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandlers([
                        RequestPipeline(application: self),
                        ResponsePipeline(application: self),
                        HandlePipeline(application: self),
                    ])
                }
            }

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: configuration.tcpNoDelay ? 1 : 0)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: configuration.reuseAddr ? 1 : 0)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: configuration.allowHalfClosure)
     
        return socketBootstrap.bind(host: configuration.host, port: configuration.port).map { channel in
            self.channel = channel
        }
    }
    
}

/// Configuration
extension Application {
    
    public struct Configuration {
        
        public var host: String
        public var port: Int
        public var backlog: Int32
        public var reuseAddr: Bool
        public var tcpNoDelay: Bool
        public var allowHalfClosure: Bool
        public var logger: String
        
        public init(host: String = "localhost",
                    port: Int = 8888,
                    backlog: Int32 = 256,
                    reuseAddr: Bool = true,
                    tcpNoDelay: Bool = true,
                    allowHalfClosure: Bool = false,
                    logger: String = "/dev/null/") {
            
            self.host = host
            self.port = port
            self.backlog = backlog
            self.reuseAddr = reuseAddr
            self.tcpNoDelay = tcpNoDelay
            self.allowHalfClosure = allowHalfClosure
            self.logger = logger
        }
    }
}
