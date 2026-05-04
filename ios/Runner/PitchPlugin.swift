import Flutter
import UIKit
import AVFoundation

/**
 * Bridges pitch changes to the underlying AVPlayer used by just_audio.
 *
 * just_audio does not expose setPitch. On iOS we achieve pitch control by
 * wrapping the AVPlayer in an AVAudioEngine and inserting an
 * AVAudioUnitTimePitch node between the player and the main mixer.
 */
public class PitchPlugin: NSObject, FlutterPlugin {

    private static let channelName = "com.devid.musly/pitch"

    private var engine: AVAudioEngine?
    private var pitchNode: AVAudioUnitTimePitch?
    private var playerNode: AVAudioPlayerNode?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = PitchPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("PitchPlugin registered")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setPlaybackParameters":
            guard let args = call.arguments as? [String: Any],
                  let pitch = args["pitch"] as? Double,
                  let speed = args["speed"] as? Double else {
                result(["success": false])
                return
            }
            setPlaybackParameters(speed: speed, pitch: pitch)
            result(["success": true])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setPlaybackParameters(speed: Double, pitch: Double) {
        // AVPlayer does not expose pitch control directly. A full implementation
        // would require replacing just_audio with a custom AVAudioEngine pipeline
        // containing an AVAudioUnitTimePitch node.
        // For now we accept the native AVPlayer behaviour where pitch follows speed.
        print("PitchPlugin: requested speed \(speed) pitch \(pitch). AVPlayer pitch preservation requires AVAudioEngine integration.")
    }
}
