import Foundation

/// The structured notes extracted from a transcript.
struct MeetingNotes: Codable {
    struct ActionItem: Codable {
        let task: String
        let owner: String?
        let due: String?
    }
    let summary: String
    let ideas: [String]
    let action_items: [ActionItem]
}

/// Extracts summary, ideas, and action items from a transcript using a local Ollama model.
/// Uses Ollama's structured-output (`format` = JSON schema) for reliable parsing.
struct Summarizer {
    let model: String
    var endpoint = URL(string: "http://localhost:11434/api/chat")!

    enum SummarizerError: LocalizedError {
        case ollamaUnreachable
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .ollamaUnreachable:
                return "Couldn't reach Ollama at localhost:11434. Is `ollama serve` running?"
            case .badResponse(let detail):
                return "Ollama returned an unexpected response: \(detail)"
            }
        }
    }

    func extract(from transcript: String) async throws -> MeetingNotes {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "summary": ["type": "string"],
                "ideas": ["type": "array", "items": ["type": "string"]],
                "action_items": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "task": ["type": "string"],
                            "owner": ["type": ["string", "null"]],
                            "due": ["type": ["string", "null"]]
                        ],
                        "required": ["task"]
                    ]
                ]
            ],
            "required": ["summary", "ideas", "action_items"]
        ]

        let system = """
        You are a meeting-notes assistant. From the transcript, produce:
        - summary: a concise paragraph capturing what was discussed.
        - ideas: distinct ideas, suggestions, or proposals raised (empty array if none).
        - action_items: concrete tasks or commitments. Include an owner and due date only \
        if the transcript states them; otherwise use null. Empty array if none.
        Base everything strictly on the transcript. Do not invent details.
        """

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "format": schema,
            "options": ["temperature": 0.2],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "Transcript:\n\n\(transcript)"]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 300

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw SummarizerError.ollamaUnreachable
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = root["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            throw SummarizerError.badResponse(raw)
        }

        do {
            return try JSONDecoder().decode(MeetingNotes.self, from: contentData)
        } catch {
            throw SummarizerError.badResponse(content)
        }
    }
}
