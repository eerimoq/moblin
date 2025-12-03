private let alertsEffectBackgroundFaceImageWidth = 130.0
private let alertsEffectBackgroundFaceImageHeight = 160.0

struct AlertsEffectBackgroundLandmarkRectangle {
    let topLeftX: Double
    let topLeftY: Double
    let bottomRightX: Double
    let bottomRightY: Double

    init(topLeftX: Double,
         topLeftY: Double,
         bottomRightX: Double,
         bottomRightY: Double)
    {
        self.topLeftX = topLeftX / alertsEffectBackgroundFaceImageWidth
        self.topLeftY = topLeftY / alertsEffectBackgroundFaceImageHeight
        self.bottomRightX = bottomRightX / alertsEffectBackgroundFaceImageWidth
        self.bottomRightY = bottomRightY / alertsEffectBackgroundFaceImageHeight
    }

    func width() -> Double {
        return bottomRightX - topLeftX
    }

    func height() -> Double {
        return bottomRightY - topLeftY
    }
}

let alertsEffectBackgroundLeftEyeRectangle = AlertsEffectBackgroundLandmarkRectangle(
    topLeftX: 40,
    topLeftY: 89,
    bottomRightX: 62,
    bottomRightY: 103
)
let alertsEffectBackgroundRightEyeRectangle = AlertsEffectBackgroundLandmarkRectangle(
    topLeftX: 72,
    topLeftY: 89,
    bottomRightX: 94,
    bottomRightY: 103
)
let alertsEffectBackgroundMouthRectangle = AlertsEffectBackgroundLandmarkRectangle(
    topLeftX: 50,
    topLeftY: 120,
    bottomRightX: 82,
    bottomRightY: 130
)
let alertsEffectBackgroundFaceRectangle = AlertsEffectBackgroundLandmarkRectangle(
    topLeftX: 25,
    topLeftY: 80,
    bottomRightX: 105,
    bottomRightY: 147
)

enum AlertsEffectFaceLandmark {
    case face
    case leftEye
    case rightEye
    case mouth
}

struct AlertsEffectLandmarkSettings {
    let landmark: AlertsEffectFaceLandmark
    let height: Double
    let centerX: Double
    let centerY: Double
}
