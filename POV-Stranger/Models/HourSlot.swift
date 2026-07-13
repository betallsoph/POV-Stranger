import Foundation
import SwiftData

@Model
final class HourSlot {
    var hourIndex: Int
    var myPhotoData: Data?
    var theirPhotoData: Data?
    var myCapturedAt: Date?
    var theirCapturedAt: Date?

    var session: StrangerSession?

    init(hourIndex: Int) {
        self.hourIndex = hourIndex
    }
}
