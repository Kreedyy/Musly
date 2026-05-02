import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Live Activity Widget View
@available(iOS 16.1, *)
struct LyricsLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsWidgetAttributes.self) { context in
            // Lock Screen / Banner View
            LyricsLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island Expanded View
            DynamicIslandExpandedRegion(.leading) {
                LyricsArtworkView(artworkUrl: context.attributes.artworkUrl)
            }
            DynamicIslandExpandedRegion(.trailing) {
                LyricsProgressView()
            }
            DynamicIslandExpandedRegion(.bottom) {
                LyricsExpandedView(context: context)
            }
        } compactLeading: {
            // Compact leading (album art)
            CompactArtworkView(artworkUrl: context.attributes.artworkUrl)
        } compactTrailing: {
            // Compact trailing (mini lyrics preview)
            CompactLyricsView(line: context.state.currentLine)
        } minimal: {
            // Minimal view
            MinimalLyricsView(line: context.state.currentLine)
        }
    }
}

// MARK: - Lock Screen View
@available(iOS 16.1, *)
struct LyricsLockScreenView: View {
    let context: ActivityViewContext<LyricsWidgetAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Song header with artwork
            HStack(spacing: 12) {
                AlbumArtworkView(artworkUrl: context.attributes.artworkUrl)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.songTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(context.attributes.artist)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Current lyrics line - highlighted
            if !context.state.currentLine.isEmpty {
                Text(context.state.currentLine)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            } else {
                Text("♪")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            }
            
            // Previous/Next lines (subtle)
            HStack {
                if let previous = context.state.previousLine, !previous.isEmpty {
                    Text(previous)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                if let next = context.state.nextLine, !next.isEmpty {
                    Text(next)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(16)
    }
}

// MARK: - Expanded Dynamic Island View
@available(iOS 16.1, *)
struct LyricsExpandedView: View {
    let context: ActivityViewContext<LyricsWidgetAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.songTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(context.attributes.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            if !context.state.currentLine.isEmpty {
                Text(context.state.currentLine)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Artwork Views
@available(iOS 16.1, *)
struct LyricsArtworkView: View {
    let artworkUrl: String?
    
    var body: some View {
        AlbumArtworkView(artworkUrl: artworkUrl)
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

@available(iOS 16.1, *)
struct CompactArtworkView: View {
    let artworkUrl: String?
    
    var body: some View {
        AlbumArtworkView(artworkUrl: artworkUrl)
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

@available(iOS 16.1, *)
struct AlbumArtworkView: View {
    let artworkUrl: String?
    
    var body: some View {
        Group {
            if let urlString = artworkUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }
    
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Compact Views
@available(iOS 16.1, *)
struct CompactLyricsView: View {
    let line: String
    
    var body: some View {
        if line.isEmpty {
            Image(systemName: "music.note")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        } else {
            Text(line.prefix(12) + (line.count > 12 ? "…" : ""))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 16.1, *)
struct MinimalLyricsView: View {
    let line: String
    
    var body: some View {
        Image(systemName: "text.quote")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
    }
}

// MARK: - Progress View
@available(iOS 16.1, *)
struct LyricsProgressView: View {
    var body: some View {
        // Could show a small waveform or equalizer animation
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: CGFloat.random(in: 8...20))
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: UUID()
                    )
            }
        }
    }
}

// MARK: - Widget Bundle
@available(iOS 16.1, *)
@main
struct LyricsWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivityWidget()
    }
}
