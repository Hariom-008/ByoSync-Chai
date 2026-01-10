import Foundation

enum DistanceGuidance: String {
    case moveCloser
    case moveFarther
    case ok
    case noFace
}

extension FaceManager{
    func updateIODGate(
        imageWidth: Float,
        imageHeight: Float,
        leftIdx: Int = 33,
        rightIdx: Int = 263,
        iodMin: Float,
        iodMax: Float
    ){

        guard imageWidth > 0, imageHeight > 0 else {
            //resetIODGate()
            return
        }

        let pts = rawMediaPipePoints
        guard pts.count > max(leftIdx, rightIdx) else{
           // resetIODGate()
            return
        }

        let l = pts[leftIdx]
        let r = pts[rightIdx]

        let lx = l.x * imageWidth
        let ly = l.y * imageHeight
        let rx = r.x * imageWidth
        let ry = r.y * imageHeight

        let dx = rx - lx
        let dy = ry - ly
        let iodPx = sqrt(dx * dx + dy * dy)
        let iodNorm = iodPx / imageWidth

        iodPixels = iodPx
        self.iodNormalized = iodNorm

        let valid = (iodNorm >= iodMin && iodNorm <= iodMax)
        self.iodIsValid = valid

        if iodNorm < iodMin {
            iodGuidance = .moveCloser
        } else if iodNorm > iodMax {
            iodGuidance = .moveFarther
        } else {
            iodGuidance = .ok
        }
    }

//    func resetIODGate() {
//        iodPixels = 0
//        iodNormalized = 0
//        iodIsValid = false
//        iodGuidance = .noFace
//    }
}
