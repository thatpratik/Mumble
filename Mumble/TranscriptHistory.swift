//
//  TranscriptHistory.swift
//  Mumble
//

import Combine
import Foundation

struct TranscriptEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date

    init(text: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
    }
}

protocol TranscriptHistoryRecording: AnyObject {
    func record(_ text: String)
}

/// Persists every finished dictation to disk so it survives app relaunches -
/// the point is a durable log the user can revisit, not just an in-memory
/// list for the current session.
final class TranscriptHistoryStore: ObservableObject, TranscriptHistoryRecording {
    @Published private(set) var entries: [TranscriptEntry] = []

    private let fileURL: URL

    init(fileURL: URL = TranscriptHistoryStore.defaultFileURL()) {
        self.fileURL = fileURL
        load()
    }

    /// TextTyper owns the empty-string no-op for typing; this mirrors that
    /// same rule for history so a very short Fn tap with no speech doesn't
    /// clutter the log with blank entries.
    func record(_ text: String) {
        guard !text.isEmpty else { return }
        entries.insert(TranscriptEntry(text: text), at: 0)
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("Mumble", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("history.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([TranscriptEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
