import Foundation
import FITSwiftSDK

enum FITFixture {
    static let start = DateTime(timestamp: 1_000_000_000)

    static func file(_ messages: [Mesg], type: FITSwiftSDK.File = .activity) throws -> Data {
        let encoder = Encoder()
        let id = FileIdMesg()
        try id.setType(type)
        try id.setManufacturer(.development)
        try id.setTimeCreated(start)
        encoder.write(mesg: id)
        encoder.write(mesgs: messages)
        return encoder.close()
    }

    static func record(latitude: Double? = 34, longitude: Double? = -118,
                       seconds: UInt32 = 0, distance: Double? = nil) throws -> RecordMesg {
        let record = RecordMesg()
        try record.setTimestamp(DateTime(timestamp: start.timestamp + seconds))
        if let latitude { try record.setPositionLat(Int32((latitude * 2_147_483_648 / 180).rounded())) }
        if let longitude { try record.setPositionLong(Int32((longitude * 2_147_483_648 / 180).rounded())) }
        if let distance { try record.setDistance(distance) }
        return record
    }

    static func session(timer: Double? = 600, elapsed: Double? = 900,
                        distance: Double? = 2000) throws -> SessionMesg {
        let session = SessionMesg()
        try session.setStartTime(start)
        try session.setTimestamp(DateTime(timestamp: start.timestamp + 900))
        if let timer { try session.setTotalTimerTime(timer) }
        if let elapsed { try session.setTotalElapsedTime(elapsed) }
        if let distance { try session.setTotalDistance(distance) }
        return session
    }
}
