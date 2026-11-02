import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct WalkingAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var steps: Int
    var calories: Int
    var points: Int
    var boosted: Bool
    var updatedAt: Date
  }
  var date: String
}
