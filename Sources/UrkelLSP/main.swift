import Foundation
import JSONRPC
import LanguageServerProtocol
import Urkel

struct UrkelLSPMain {
    static func main() async {
        await UrkelLSPRunner().run()
    }
}

private struct UrkelLSPRunner {
    private let server = UrkelLanguageServer()

    func run() async {
        let session = JSONRPCSession(channel: DataChannel.stdio())
        let events = await session.eventSequence
        var shouldExit = false

        for await event in events {
            switch event {
            case let .notification(notification, data):
                shouldExit = await handleNotification(notification, data: data, session: session)
                if shouldExit { return }
            case let .request(request, handler, data):
                await handleRequest(request, data: data, handler: handler)
            case let .error(error):
                fputs("urkel-lsp error: \(error)\n", stderr)
            }
        }
    }

    private func handleNotification(
        _ notification: AnyJSONRPCNotification,
        data: Data,
        session: JSONRPCSession
    ) async -> Bool {
        switch notification.method {
        case "initialized", "window/logMessage", "window/showMessage":
            return false
        case "exit":
            return true
        case "textDocument/didOpen":
            do {
                let params = try decodeNotificationParams(DidOpenTextDocumentParams.self, from: data)
                let response = await server.didOpen(
                    uri: params.textDocument.uri,
                    text: params.textDocument.text,
                    version: params.textDocument.version
                )
                try await session.sendNotification(response, method: "textDocument/publishDiagnostics")
            } catch {
                fputs("urkel-lsp didOpen error: \(error)\n", stderr)
            }
            case "textDocument/didChange":
            do {
                let params = try decodeNotificationParams(DidChangeTextDocumentParams.self, from: data)
                guard let text = params.contentChanges.last?.text else { return false }
                let response = await server.didChange(
                    uri: params.textDocument.uri,
                    text: text,
                    version: params.textDocument.version
                )
                try await session.sendNotification(response, method: "textDocument/publishDiagnostics")
            } catch {
                fputs("urkel-lsp didChange error: \(error)\n", stderr)
            }
        case "textDocument/didClose":
            do {
                let params = try decodeNotificationParams(DidCloseTextDocumentParams.self, from: data)
                let response = await server.didClose(uri: params.textDocument.uri)
                try await session.sendNotification(response, method: "textDocument/publishDiagnostics")
            } catch {
                fputs("urkel-lsp didClose error: \(error)\n", stderr)
            }
        default:
            return false
        }

        return false
    }

    private func handleRequest(
        _ request: AnyJSONRPCRequest,
        data: Data,
        handler: @escaping JSONRPCEvent.RequestHandler
    ) async {
        do {
            switch request.method {
            case "initialize":
                let params = try decodeRequestParams(InitializeParams.self, from: data)
                _ = params
                let response = await server.initializationResponse()
                await handler(.success(response))
            case "shutdown":
                await handler(.success(JSONValue.null))
            case "textDocument/completion":
                let params = try decodeRequestParams(CompletionParams.self, from: data)
                if let response = await server.completion(for: params.textDocument.uri, position: params.position) {
                    await handler(.success(response))
                } else {
                    await handler(.success(JSONValue.null))
                }
            case "textDocument/hover":
                let params = try decodeRequestParams(TextDocumentPositionParams.self, from: data)
                if let response = await server.hover(for: params.textDocument.uri, position: params.position) {
                    await handler(.success(response))
                } else {
                    await handler(.success(JSONValue.null))
                }
            case "textDocument/formatting":
                let params = try decodeRequestParams(DocumentFormattingParams.self, from: data)
                let edits = await server.formattingEdits(for: params.textDocument.uri)
                await handler(.success(edits))
            case "textDocument/rangeFormatting":
                let params = try decodeRequestParams(DocumentRangeFormattingParams.self, from: data)
                let edits = await server.formattingEdits(for: params.textDocument.uri)
                await handler(.success(edits))
            case "textDocument/codeAction":
                let params = try decodeRequestParams(CodeActionParams.self, from: data)
                if let response = await server.codeActions(
                    for: params.textDocument.uri,
                    params.range,
                    diagnostics: params.context.diagnostics
                ) {
                    await handler(.success(response))
                } else {
                    await handler(.success(JSONValue.null))
                }
            case "textDocument/semanticTokens/full":
                let params = try decodeRequestParams(SemanticTokensParams.self, from: data)
                if let response = await server.semanticTokens(for: params.textDocument.uri) {
                    await handler(.success(response))
                } else {
                    await handler(.success(JSONValue.null))
                }
            case "textDocument/diagnostic":
                let params = try decodeRequestParams(DocumentDiagnosticParams.self, from: data)
                guard let diagnostics = await server.diagnostics(for: params.textDocument.uri) else {
                    await handler(.success(JSONValue.null))
                    return
                }
                let report = DocumentDiagnosticReport(kind: .full, resultId: nil, items: diagnostics, relatedDocuments: nil)
                await handler(.success(report))
            default:
                await handler(.failure(JSONRPCResponseError(code: -32601, message: "Unsupported method: \(request.method)")))
            }
        } catch let error as JSONRPCResponseError<JSONValue> {
            await handler(.failure(error))
        } catch {
            await handler(.failure(JSONRPCResponseError(code: -32603, message: error.localizedDescription)))
        }
    }

    private func decodeRequestParams<Params: Decodable>(_ type: Params.Type, from data: Data) throws -> Params {
        let request = try JSONDecoder().decode(JSONRPCRequest<Params>.self, from: data)
        guard let params = request.params else {
            throw JSONRPCResponseError<JSONValue>(code: -32602, message: "Missing params")
        }
        return params
    }

    private func decodeNotificationParams<Params: Decodable>(_ type: Params.Type, from data: Data) throws -> Params {
        let notification = try JSONDecoder().decode(JSONRPCNotification<Params>.self, from: data)
        guard let params = notification.params else {
            throw JSONRPCResponseError<JSONValue>(code: -32602, message: "Missing params")
        }
        return params
    }
}
