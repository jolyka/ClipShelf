import Foundation

enum ClipboardContentKind: String, Codable, Hashable {
    case image
    case text
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: ClipboardContentKind
    let filename: String?
    let text: String?
    let createdAt: Date
    let pixelWidth: Int?
    let pixelHeight: Int?
    let byteCount: Int
    let digest: String

    init(
        id: UUID,
        kind: ClipboardContentKind,
        filename: String? = nil,
        text: String? = nil,
        createdAt: Date,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        byteCount: Int,
        digest: String
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.text = text
        self.createdAt = createdAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.digest = digest
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, filename, text, createdAt, pixelWidth, pixelHeight, byteCount, digest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        kind = try container.decodeIfPresent(ClipboardContentKind.self, forKey: .kind)
            ?? (filename == nil ? .text : .image)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        pixelWidth = try container.decodeIfPresent(Int.self, forKey: .pixelWidth)
        pixelHeight = try container.decodeIfPresent(Int.self, forKey: .pixelHeight)
        byteCount = try container.decode(Int.self, forKey: .byteCount)
        digest = try container.decode(String.self, forKey: .digest)
    }
}
