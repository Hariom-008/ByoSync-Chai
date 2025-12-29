import SwiftUI
import Foundation
import CoreGraphics

extension FaceManager {

    /// Android-equivalent: pixel coordinates + Euclidean distance + pixel tolerance
    func updateNoseTipCenterStatusFromCalcCoords(
        pixelPoints: [CGPoint],
        screenCenterX: CGFloat,
        screenCenterY: CGFloat,
        tolerancePx: CGFloat = 10.0
    ){
        guard pixelPoints.count > 4 else {
            self.isNoseTipCentered = false
            return
        }

        let nose = pixelPoints[4]
        let dx = nose.x - screenCenterX
        let dy = nose.y - screenCenterY
        let distance = sqrt(dx * dx + dy * dy)

        self.isNoseTipCentered = distance <= tolerancePx
    }
}
