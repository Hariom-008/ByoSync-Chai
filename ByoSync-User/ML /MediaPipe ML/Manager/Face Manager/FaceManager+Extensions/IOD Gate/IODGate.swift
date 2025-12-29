import Foundation

enum DistanceGuidance: String {
    case moveCloser
    case moveFarther
    case ok
    case noFace
}

extension FaceManager{
    
    func updateIODGate(
        frameWidth: Float,
        frameHeight: Float,
        leftIdx: Int = 33,
        rightIdx: Int = 263,
        iodMin: Float = 0.30,
        iodMax: Float = 0.31
    ){

        guard frameWidth > 0, frameHeight > 0 else {
            resetIODGate()
            return
        }

        let pts = rawMediaPipePoints
        guard pts.count > max(leftIdx, rightIdx) else{
            resetIODGate()
            return
        }

        let l = pts[leftIdx]
        let r = pts[rightIdx]

        let lx = l.x * frameWidth
        let ly = l.y * frameHeight
        let rx = r.x * frameWidth
        let ry = r.y * frameHeight

        let dx = rx - lx
        let dy = ry - ly
        let iodPx = sqrt(dx * dx + dy * dy)
        let iodNorm = iodPx / frameWidth

        iodPixels = iodPx
        iodNormalized = iodNorm

        let valid = (iodNorm >= iodMin && iodNorm <= iodMax)
        iodIsValid = valid

        if iodNorm < iodMin {
            iodGuidance = .moveCloser
        } else if iodNorm > iodMax {
            iodGuidance = .moveFarther
        } else {
            iodGuidance = .ok
        }
    }

    func resetIODGate() {
        iodPixels = 0
        iodNormalized = 0
        iodIsValid = false
        iodGuidance = .noFace
    }
}
