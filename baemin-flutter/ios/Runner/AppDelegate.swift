import Flutter
import UIKit
import CoreMotion
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  static var openWalkingPending = false
  private let pedometer = CMPedometer()
  private let livePedometer = CMPedometer()
  private var stepsSink: FlutterEventSink?
  private var streamStart: Date?
  private var liveArguments: [String: Any] = [:]

  private var walkingCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
  }
  private func walkingDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = walkingCalendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = walkingCalendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stepsSink = events
    startWalkingUpdates()
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stepsSink = nil
    livePedometer.stopUpdates()
    streamStart = nil
    return nil
  }
  private func startWalkingUpdates() {
    guard stepsSink != nil, CMPedometer.isStepCountingAvailable(),
          CMPedometer.authorizationStatus() == .authorized else { return }
    let start = walkingCalendar.startOfDay(for: Date())
    guard streamStart != start else { return }
    livePedometer.stopUpdates()
    streamStart = start
    livePedometer.startUpdates(from: start) { [weak self] data, error in
      DispatchQueue.main.async {
        guard let self = self, self.streamStart == start else { return }
        guard CMPedometer.authorizationStatus() == .authorized else {
          self.stepsSink?(["status": "denied"])
          self.livePedometer.stopUpdates()
          self.streamStart = nil
          return
        }
        guard self.walkingCalendar.isDate(start, inSameDayAs: Date()) else {
          self.startWalkingUpdates(); return
        }
        guard let data = data, error == nil else { return }
        self.stepsSink?([
          "status": "authorized", "date": self.walkingDate(data.endDate),
          "steps": data.numberOfSteps.intValue,
          "measuredAt": Int(data.endDate.timeIntervalSince1970 * 1000)
        ])
        // Native callbacks may still arrive while background execution is
        // available. They are not a way to keep a suspended app running.
        if UIApplication.shared.applicationState != .active {
          if #available(iOS 16.2, *) {
            self.updateActivityFromMotion(steps: data.numberOfSteps.intValue, date: self.walkingDate(data.endDate))
          }
        }
      }
    }
  }

  @available(iOS 16.2, *)
  private func updateActivityFromMotion(steps: Int, date: String) {
    guard liveArguments["date"] as? String == date else { return }
    let boosted = liveArguments["boosted"] as? Bool ?? false
    let earned = (max(0, min(steps, 10000)) / 1000) * 4 * (boosted ? 2 : 1)
    let points = max(0, earned - (liveArguments["claimed"] as? Int ?? 0))
    let state = WalkingAttributes.ContentState(
      steps: steps, calories: Int((Double(steps) * 0.0327).rounded()),
      points: points, boosted: boosted, updatedAt: Date())
    Task { @MainActor in
      for activity in Activity<WalkingAttributes>.activities where activity.attributes.date == date {
        if activity.activityState == .active || activity.activityState == .stale {
          await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(120)))
        }
      }
    }
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "hankki/walking", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    let events = FlutterEventChannel(name: "hankki/walking/events", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    events.setStreamHandler(self)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "takeOpenWalking" {
        let pending = AppDelegate.openWalkingPending
        AppDelegate.openWalkingPending = false
        result(pending); return
      }
      if ["liveStart", "liveUpdate", "liveStop"].contains(call.method) {
        guard #available(iOS 16.2, *) else {
          result(FlutterError(code: "unsupported", message: "잠금화면 표시는 iOS 16.2 이상에서 사용할 수 있어요.", details: nil)); return
        }
        self?.handleWalkingActivity(call, result: result)
        return
      }
      guard call.method == "today" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { return }
      guard CMPedometer.isStepCountingAvailable() else { result(["status": "unsupported"]); return }
      let status = CMPedometer.authorizationStatus()
      if status == .denied || status == .restricted { result(["status": "denied"]); return }
      let args = call.arguments as? [String: Any]
      if status == .notDetermined && args?["request"] as? Bool != true {
        result(["status": "unlinked"]); return
      }
      let now = Date()
      let start = self.walkingCalendar.startOfDay(for: now)
      let date = self.walkingDate(now)
      self.startWalkingUpdates()
      self.pedometer.queryPedometerData(from: start, to: now) { data, error in
        DispatchQueue.main.async {
          if CMPedometer.authorizationStatus() == .denied || CMPedometer.authorizationStatus() == .restricted {
            result(["status": "denied"])
          } else if let data = data, error == nil {
            self.startWalkingUpdates()
            result(["status": "authorized", "date": date, "steps": data.numberOfSteps.intValue,
                    "measuredAt": Int(now.timeIntervalSince1970 * 1000)])
          } else {
            result(FlutterError(code: "walking_unavailable", message: "걸음 수를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.", details: nil))
          }
        }
      }
    }
  }

  @available(iOS 16.2, *)
  private func handleWalkingActivity(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    Task { @MainActor in
      if call.method == "liveStop" {
        self.liveArguments = [:]
        for activity in Activity<WalkingAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
        result(false); return
      }
      guard CMPedometer.authorizationStatus() == .authorized else {
        result(FlutterError(code: "motion_required", message: "아이폰 걸음 수를 먼저 연결해 주세요.", details: nil)); return
      }
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        result(FlutterError(code: "live_denied", message: "아이폰 설정에서 한 끼 캘린더의 실시간 현황을 허용해 주세요.", details: nil)); return
      }
      self.liveArguments = args
      let date = args["date"] as? String ?? ""
      let state = WalkingAttributes.ContentState(
        steps: max(0, min(args["steps"] as? Int ?? 0, 200000)),
        calories: max(0, args["calories"] as? Int ?? 0),
        points: max(0, min(args["points"] as? Int ?? 0, 80)),
        boosted: args["boosted"] as? Bool ?? false,
        updatedAt: Date())
      // Old values are explicitly marked stale; no continuous background measurement is claimed.
      let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
      var existing: Activity<WalkingAttributes>?
      for activity in Activity<WalkingAttributes>.activities {
        if activity.attributes.date != date {
          await activity.end(nil, dismissalPolicy: .immediate)
        } else if activity.activityState == .active || activity.activityState == .stale {
          existing = activity
        }
      }
      if let activity = existing {
        await activity.update(content)
        result(true)
      } else if call.method == "liveStart" {
        do {
          _ = try Activity.request(attributes: WalkingAttributes(date: date), content: content, pushType: nil)
          result(true)
        } catch {
          result(FlutterError(code: "live_failed", message: "실시간 현황을 시작하지 못했어요. 앱을 연 상태에서 다시 시도해 주세요.", details: nil))
        }
      } else {
        // Don't recreate a Live Activity the person dismissed or iOS ended.
        result(false)
      }
    }
  }
}
