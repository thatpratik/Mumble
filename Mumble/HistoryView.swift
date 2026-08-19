//
//  HistoryView.swift
//  Mumble
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: TranscriptHistoryStore

    var body: some View {
        NavigationStack {
            Group {
                if history.entries.isEmpty {
                    ContentUnavailableView(
                        "No dictation yet",
                        systemImage: "mic.slash",
                        description: Text("Hold Fn and speak - what you say will show up here.")
                    )
                } else {
                    List(history.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text)
                            Text(entry.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Mumble History")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Clear", role: .destructive) {
                        history.clear()
                    }
                    .disabled(history.entries.isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }
}
