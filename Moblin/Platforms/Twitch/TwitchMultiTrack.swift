import AppleGPUInfo
import VideoToolbox

private let ingestUrl = "https://ingest.twitch.tv/api/v3/GetClientConfiguration"

struct TwitchMultiTrackGetClientConfigurationIngestEndpoint: Codable {
    let proto: String
    let url_template: String
    let authentication: String

    private enum CodingKeys: String, CodingKey {
        case proto = "protocol"
        case url_template
        case authentication
    }
}

struct TwitchMultiTrackGetClientConfigurationFrameRate: Codable {
    // periphery:ignore
    let numerator: Int
    // periphery:ignore
    let denominator: Int
}

struct TwitchMultiTrackGetClientConfigurationEncoderContigurationSettings: Codable {
    let bitrate: UInt32
    let bframes: Bool
    let keyint_sec: Int32
    let profile: String
    // periphery:ignore
    let rate_control: String
}

struct TwitchMultiTrackGetClientConfigurationEncoderContiguration: Codable {
    let type: String
    // periphery:ignore
    let bitrate_interpolation_points: [Int]
    // periphery:ignore
    let framerate: TwitchMultiTrackGetClientConfigurationFrameRate
    // periphery:ignore
    let gpu_scale_type: String
    let width: Int32
    let height: Int32
    let settings: TwitchMultiTrackGetClientConfigurationEncoderContigurationSettings
}

struct TwitchMultiTrackGetClientConfigurationAudioTrackSettings: Codable {
    // periphery:ignore
    let bitrate: Int
}

struct TwitchMultiTrackGetClientConfigurationAudioTrackConfiguration: Codable {
    // periphery:ignore
    let codec: String
    // periphery:ignore
    let track_id: Int
    // periphery:ignore
    let channels: Int
    // periphery:ignore
    let settings: TwitchMultiTrackGetClientConfigurationAudioTrackSettings
}

struct TwitchMultiTrackGetClientConfigurationAudioConfigurations: Codable {
    // periphery:ignore
    let live: [TwitchMultiTrackGetClientConfigurationAudioTrackConfiguration]
}

struct TwitchMultiTrackGetClientConfigurationResponse: Codable {
    let ingest_endpoints: [TwitchMultiTrackGetClientConfigurationIngestEndpoint]
    let encoder_configurations: [TwitchMultiTrackGetClientConfigurationEncoderContiguration]
    // periphery:ignore
    let audio_configurations: TwitchMultiTrackGetClientConfigurationAudioConfigurations
}

func twitchMultiTrackGetClientConfiguration(
    url: String,
    dimensions: CMVideoDimensions,
    fps: Int,
    onCompelte: @escaping (TwitchMultiTrackGetClientConfigurationResponse?) -> Void
) {
    guard let ingestUrl = URL(string: ingestUrl) else {
        onCompelte(nil)
        return
    }
    var request = URLRequest(url: ingestUrl)
    request.httpMethod = "POST"
    guard let streamKey = url.split(separator: "/").last else {
        onCompelte(nil)
        return
    }
    let processInfo = ProcessInfo.processInfo
    guard let gpuInfo = try? GPUInfoDevice() else {
        onCompelte(nil)
        return
    }
    request.httpBody = """
    {
        "authentication": "\(streamKey)",
        "capabilities": {
            "cpu": {
                "logical_cores": \(processInfo.activeProcessorCount),
                "name": null,
                "physical_cores": \(processInfo.processorCount),
                "speed": null
            },
            "gaming_features": null,
            "gpu": [
                {
                    "dedicated_video_memory": \(gpuInfo.memory),
                    "device_id": 0,
                    "driver_version": null,
                    "model": "\(gpuInfo.name)",
                    "shared_system_memory": \(gpuInfo.memory),
                    "vendor_id": null
                }
            ],
            "memory": {
                "free": \(processInfo.physicalMemory / 2),
                "total": \(processInfo.physicalMemory)
            },
            "system": {
                "build": 0,
                "name": "iOS",
                "release": null,
                "revision": null,
                "version": "\(processInfo.operatingSystemVersionString)"
            }
        },
        "client": {
            "name": "moblin",
            "supported_codecs": [
                "h265",
                "h264"
            ],
            "version": "0.389.0"
        },
        "preferences": {
            "canvas_height": \(dimensions.height),
            "canvas_width": \(dimensions.width),
            "composition_gpu_index": 0,
            "framerate": {
                "denominator": 1,
                "numerator": \(fps)
            },
            "height": \(dimensions.height),
            "maximum_aggregate_bitrate": null,
            "maximum_video_tracks": null,
            "vod_track_audio": false,
            "width": \(dimensions.width)
        },
        "schema_version": "2024-06-04",
        "service": "IVS"
    }
    """.utf8Data
    URLSession.shared.dataTask(with: request) { data, response, _ in
        guard response?.http?.isSuccessful == true else {
            onCompelte(nil)
            return
        }
        guard let data else {
            onCompelte(nil)
            return
        }
        do {
            let response = try JSONDecoder().decode(TwitchMultiTrackGetClientConfigurationResponse.self, from: data)
            onCompelte(response)
        } catch {
            onCompelte(nil)
        }
    }
    .resume()
}
