import Flutter
import UIKit
import ActivityKit

/// Plugin to manage synchronized lyrics on iOS Lock Screen via Live Activities
public class iOSLyricsPlugin: NSObject, FlutterPlugin {
    
    private static let methodChannelName = "com.devid.musly/lyrics"
    private static let eventChannelName = "com.devid.musly/lyrics_updates"
    
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    /// Current Live Activity
    private var currentActivity: Activity<LyricsWidgetAttributes>?
    
    /// Last known song info for Live Activity
    private var currentSongTitle: String = ""
    private var currentArtist: String = ""
    private var currentArtworkUrl: String? = nil
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = iOSLyricsPlugin()
        
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        
        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        
        print("iOSLyricsPlugin registered")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Check if Live Activities are available (iOS 16.1+)
        guard #available(iOS 16.1, *) else {
            result(FlutterError(
                code: "UNAVAILABLE",
                message: "Live Activities require iOS 16.1+",
                details: nil
            ))
            return
        }
        
        switch call.method {
        case "initialize":
            initialize(result: result)
            
        case "lyricsAvailable":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            handleLyricsAvailable(args: args, result: result)
            
        case "updateLyrics":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            updateLyrics(args: args, result: result)
            
        case "updateSongInfo":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            updateSongInfo(args: args, result: result)
            
        case "clearLyrics":
            endLiveActivity(result: result)
            
        case "dispose":
            endLiveActivity(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    @available(iOS 16.1, *)
    private func initialize(result: @escaping FlutterResult) {
        // Check if Live Activities are supported
        let supportsLiveActivities = ActivityAuthorizationInfo().areActivitiesEnabled
        result(["supportsLiveActivities": supportsLiveActivities])
    }
    
    @available(iOS 16.1, *)
    private func handleLyricsAvailable(args: [String: Any], result: @escaping FlutterResult) {
        let hasLyrics = args["hasLyrics"] as? Bool ?? false
        
        if hasLyrics {
            // Start Live Activity when lyrics are available
            startLiveActivity(initialLine: args["initialLine"] as? String)
            result(["started": true])
        } else {
            endLiveActivity(result: result)
        }
    }
    
    @available(iOS 16.1, *)
    private func updateLyrics(args: [String: Any], result: @escaping FlutterResult) {
        guard let currentLine = args["currentLine"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing currentLine", details: nil))
            return
        }
        
        // Update the Live Activity with the new lyrics line
        updateLiveActivity(currentLine: currentLine)
        result(["updated": true])
    }
    
    @available(iOS 16.1, *)
    private func updateSongInfo(args: [String: Any], result: @escaping FlutterResult) {
        currentSongTitle = args["title"] as? String ?? ""
        currentArtist = args["artist"] as? String ?? ""
        currentArtworkUrl = args["artworkUrl"] as? String
        result(nil)
    }
    
    @available(iOS 16.1, *)
    private func startLiveActivity(initialLine: String?) {
        // End any existing activity first
        if let activity = currentActivity {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        let attributes = LyricsWidgetAttributes(
            songTitle: currentSongTitle,
            artist: currentArtist,
            artworkUrl: currentArtworkUrl
        )
        
        let contentState = LyricsWidgetAttributes.ContentState(
            currentLine: initialLine ?? "",
            previousLine: nil,
            nextLine: nil
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            currentActivity = activity
            print("Started Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    @available(iOS 16.1, *)
    private func updateLiveActivity(currentLine: String) {
        guard let activity = currentActivity else {
            // Start activity if not running
            startLiveActivity(initialLine: currentLine)
            return
        }
        
        let updatedState = LyricsWidgetAttributes.ContentState(
            currentLine: currentLine,
            previousLine: nil,
            nextLine: nil
        )
        
        Task {
            await activity.update(using: updatedState)
        }
    }
    
    private func endLiveActivity(result: FlutterResult? = nil) {
        guard #available(iOS 16.1, *) else {
            result?(nil)
            return
        }
        
        guard let activity = currentActivity else {
            result?(nil)
            return
        }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            result?(["ended": true])
        }
    }
}

// MARK: - FlutterStreamHandler
extension iOSLyricsPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - Live Activity Attributes
@available(iOS 16.1, *)
struct LyricsWidgetAttributes: ActivityAttributes {
    /// Static data about the song
    public struct ContentState: Codable, Hashable {
        var currentLine: String
        var previousLine: String?
        var nextLine: String?
    }
    
    /// Fixed song metadata
    var songTitle: String
    var artist: String
    var artworkUrl: String?
}
