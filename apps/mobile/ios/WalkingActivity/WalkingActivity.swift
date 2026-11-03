import ActivityKit
import SwiftUI
import WidgetKit

private let mint = Color(red: 12.0/255, green: 239.0/255, blue: 211.0/255)
private func walkingFont(_ size: CGFloat, bold: Bool = false) -> Font {
  .custom(bold ? "NotoSansKR-Thin_Bold" : "NotoSansKR-Thin_Regular", size: size)
}
private let destination = URL(string: "hankki://walking")!

@main
struct WalkingWidgets: WidgetBundle {
  var body: some Widget { WalkingActivityWidget() }
}

struct WalkingActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WalkingAttributes.self) { context in
      HStack(spacing: 12) {
        Image("WalkingLogo")
          .resizable().scaledToFit().frame(width: 50, height: 48)
          .accessibilityLabel("배민 만보기")
        VStack(alignment: .leading, spacing: 3) {
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(context.state.steps.formatted())
              .font(walkingFont(24, bold: true)).monospacedDigit()
              .contentTransition(.numericText())
            Text("걸음").font(walkingFont(16, bold: true))
              .foregroundStyle(Color(red: 224.0/255, green: 233.0/255, blue: 232.0/255))
          }
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("소비 칼로리").font(walkingFont(10))
            Text("\(context.state.calories) kcal").font(walkingFont(16, bold: true))
          }
          if context.isStale {
            Text("앱에서 최신 걸음 확인").font(walkingFont(10)).foregroundStyle(mint)
          }
        }.foregroundStyle(.white).minimumScaleFactor(0.7).lineLimit(1)
        Spacer(minLength: 0)
        VStack(spacing: 5) {
          Text(context.state.boosted ? "픽업 부스터 X2" : "오늘의 걸음 보상")
            .font(walkingFont(10, bold: true)).lineLimit(1).minimumScaleFactor(0.8)
          Text("\(context.state.points)P").font(walkingFont(16, bold: true)).monospacedDigit()
          Link(destination: destination) {
            Text(context.state.points > 0 ? "보상 받기" : "걸음 확인")
              .font(walkingFont(10, bold: true))
              .foregroundStyle(Color(red: 17.0/255, green: 17.0/255, blue: 17.0/255))
              .frame(width: 64, height: 28)
              .background(mint, in: RoundedRectangle(cornerRadius: 8))
          }
        }.foregroundStyle(mint).frame(width: 64, height: 70).padding(.horizontal, 12).padding(.vertical, 8)
          .background(
            LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.04)],
              startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
      }.padding(8)
        .background {
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay {
              RoundedRectangle(cornerRadius: 16).fill(
                LinearGradient(colors: [
                  Color(red: 91.0/255, green: 112.0/255, blue: 116.0/255).opacity(0.62),
                  Color(red: 56.0/255, green: 73.0/255, blue: 78.0/255).opacity(0.7),
                  Color(red: 44.0/255, green: 60.0/255, blue: 64.0/255).opacity(0.8)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
              LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75))
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(mint)
        .widgetURL(destination)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("만보기", systemImage: "figure.walk").font(.headline).foregroundStyle(mint)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(context.state.points)P").font(.title2.bold()).foregroundStyle(mint)
        }
        DynamicIslandExpandedRegion(.center) {
          Text("\(context.state.steps.formatted()) 걸음").font(.headline).monospacedDigit()
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text("소비 칼로리 \(context.state.calories) kcal").font(.caption)
            Spacer()
            Link(context.state.points > 0 ? "보상 받기 ›" : "걸음 확인 ›", destination: destination).font(.headline).foregroundStyle(mint)
          }.padding(.top, 6)
        }
      } compactLeading: {
        Image("WalkingLogo").resizable().scaledToFit().frame(width: 20, height: 20)
      } compactTrailing: {
        Text(context.state.steps.formatted()).font(.caption.bold()).monospacedDigit().foregroundStyle(mint)
      } minimal: {
        Image("WalkingLogo").resizable().scaledToFit().frame(width: 20, height: 20)
      }.widgetURL(destination).keylineTint(mint)
    }
  }
}
