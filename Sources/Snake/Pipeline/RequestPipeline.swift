//
//  RequestPipeline.swift
//  Snake
//
//  Created by panghu on 7/10/20.
//

final class RequestPipeline: ChannelInboundHandler, RemovableChannelHandler {
    
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = MessageRequest
    
    enum State {
        case ready
        case awaitingBody(MessageRequest, MessageByteStream)
        case awaitingEnd(MessageRequest, MessageByteStream)
        case streamingBody(MessageRequest, MessageByteStream)
    }

    var state: State
    let application: Application
    
    init(application: Application) {
        self.state = .ready
        self.application = application
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            switch state {
            case .ready:
                let stream = MessageByteStream()
                let request = MessageRequest(head: head, stream: stream)
                context.fireChannelRead(wrapInboundOut(request))
                state = .awaitingBody(request, stream)
            default:
                assertionFailure("Unexpected state: \(state)")
            }
        case .body(let byteBuffer):
            switch state {
            case .awaitingBody(let request, let stream):
                stream.write(.bytes(byteBuffer))
                state = .streamingBody(request, stream)
            case .streamingBody(_, let stream):
                stream.write(.bytes(byteBuffer))
            case .ready, .awaitingEnd:
                assertionFailure("Unexpected state: \(state)")
            }
        case .end(let headers):
            switch state {
            case .awaitingBody(let request, let stream):
                stream.write(.end(headers))
                state = .awaitingEnd(request, stream)
            case .awaitingEnd(let request, let stream):
                stream.write(.end(headers))
                state = .awaitingEnd(request, stream)
            case .streamingBody(let request, let stream):
                stream.write(.end(headers))
                state = .awaitingEnd(request, stream)
            case .ready:
                assertionFailure("Unexpected state: \(state)")
            }
        }
    }
}
