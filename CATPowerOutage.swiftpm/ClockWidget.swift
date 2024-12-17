import SwiftUI
import UIKit

extension UIViewController {
    func topmostViewController() -> UIViewController {
        if let presented = self.presentedViewController {
            return presented.topmostViewController()
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topmostViewController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topmostViewController() ?? tab
        }
        return self
    }
}

// A separate view for snapshotting to PNG (no button, no recursion)
private struct ClockSnapshotView: View {
    var cherga: Int
    var subCherga: Int
    var outageTimes: [(start: String, end: String)]
    var caption: String
    var nonOutageColor: Color
    var outageColor: Color

    var body: some View {
        let subChergaText = subCherga == 1 ? "І підчерга" : "ІІ підчерга"
        let (totalHours, totalMinutes) = totalOutageDuration(outageTimes: outageTimes)

        VStack {
            Text("Черга \(cherga) (\(subChergaText))")
                .font(.headline)
                .padding(.bottom, 2)

            Text(caption)
                .font(.headline)
                .padding(.bottom, 10)

            GeometryReader { geometry in
                let radius = min(geometry.size.width, geometry.size.height) / 2
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ZStack {
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundColor(.gray)

                    ForEach(0..<48) { index in
                        let startAngle = Angle.degrees(Double(index) / 48.0 * 360.0 - 90)
                        let endAngle = Angle.degrees(Double(index + 1) / 48.0 * 360.0 - 90)

                        let isOutage = timeInOutage(index: index, outageTimes: outageTimes)

                        Path { path in
                            path.move(to: center)
                            path.addArc(center: center, radius: radius,
                                        startAngle: startAngle,
                                        endAngle: endAngle, clockwise: false)
                            path.closeSubpath()
                        }
                        .fill(isOutage ? outageColor : nonOutageColor)

                        // Label hours on even indices
                        if index % 2 == 0 {
                            let hour = index / 2
                            let numberAngle = Angle.degrees(Double(index) / 48.0 * 360.0 - 90)
                            let numberPosition = CGPoint(
                                x: center.x + radius * 0.85 * cos(CGFloat(numberAngle.radians)),
                                y: center.y + radius * 0.85 * sin(CGFloat(numberAngle.radians))
                            )

                            Text("\(hour)")
                                .font(.system(size: 10))
                                .position(numberPosition)
                                .foregroundColor(.black)
                        }
                    }

                    // Hour dividers
                    ForEach(0..<24) { hourMark in
                        let angle = Angle.degrees(Double(hourMark) / 24.0 * 360.0 - 90)
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: CGPoint(
                                x: center.x + radius * cos(CGFloat(angle.radians)),
                                y: center.y + radius * sin(CGFloat(angle.radians))
                            ))
                        }
                        .stroke(Color.black, lineWidth: 1)
                    }

                    // Half-hour dividers
                    ForEach(0..<48) { halfMark in
                        if halfMark % 2 != 0 {
                            let angle = Angle.degrees(Double(halfMark) / 48.0 * 360.0 - 90)
                            Path { path in
                                path.move(to: center)
                                path.addLine(to: CGPoint(
                                    x: center.x + radius * cos(CGFloat(angle.radians)),
                                    y: center.y + radius * sin(CGFloat(angle.radians))
                                ))
                            }
                            .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(Color.white)
            
            // Total outage duration
            Text("Загальна тривалість: \(totalHours) год \(totalMinutes) хв")
                .font(.subheadline)
                .padding(.top, 10)
        }
        .frame(width: 300, height: 400) // Increased height to accommodate duration text
    }

    func timeInOutage(index: Int, outageTimes: [(start: String, end: String)]) -> Bool {
        let segmentMinutes = index * 30
        for time in outageTimes {
            guard let startHour = Int(time.start.prefix(2)),
                  let startMinute = Int(time.start.suffix(2)),
                  let endHour = Int(time.end.prefix(2)),
                  let endMinute = Int(time.end.suffix(2)) else {
                continue
            }

            let startTotal = startHour * 60 + startMinute
            let endTotal = endHour * 60 + endMinute

            if startTotal <= endTotal {
                if segmentMinutes >= startTotal && segmentMinutes < endTotal {
                    return true
                }
            } else {
                // wraps past midnight
                if segmentMinutes >= startTotal || segmentMinutes < endTotal {
                    return true
                }
            }
        }
        return false
    }

    func totalOutageDuration(outageTimes: [(start: String, end: String)]) -> (Int, Int) {
        var totalMinutes = 0
        for time in outageTimes {
            if let startHour = Int(time.start.prefix(2)),
               let startMinute = Int(time.start.suffix(2)),
               let endHour = Int(time.end.prefix(2)),
               let endMinute = Int(time.end.suffix(2)) {
                let startTotal = startHour * 60 + startMinute
                let endTotal = endHour * 60 + endMinute
                // If end < start, wrap around midnight scenario
                if endTotal >= startTotal {
                    totalMinutes += (endTotal - startTotal)
                } else {
                    // Wraps to next day
                    totalMinutes += ((24*60 - startTotal) + endTotal)
                }
            }
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return (hours, minutes)
    }
}

struct ClockView: View {
    var cherga: Int
    var subCherga: Int
    var outageTimes: [(start: String, end: String)]
    var nonOutageColor: Color = .green
    var outageColor: Color = .red
    var caption: String

    @State private var showShareSheet = false
    @State private var generatedImage: UIImage? = nil

    var body: some View {
        let subChergaText = subCherga == 1 ? "І підчерга" : "ІІ підчерга"
        let (totalHours, totalMinutes) = totalOutageDuration(outageTimes: outageTimes)

        VStack {
            // Show captions and chart in the live UI
            Text("Черга \(cherga) (\(subChergaText))")
                .font(.headline)
                .padding(.bottom, 2)

            Text(caption)
                .font(.headline)
                .padding(.bottom, 10)

            GeometryReader { geometry in
                let radius = min(geometry.size.width, geometry.size.height) / 2
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ZStack {
                    Circle()
                        .stroke(lineWidth: 2)
                        .foregroundColor(.gray)

                    ForEach(0..<48) { index in
                        let startAngle = Angle.degrees(Double(index) / 48.0 * 360.0 - 90)
                        let endAngle = Angle.degrees(Double(index + 1) / 48.0 * 360.0 - 90)

                        let isOutage = timeInOutage(index: index)

                        Path { path in
                            path.move(to: center)
                            path.addArc(center: center, radius: radius,
                                        startAngle: startAngle,
                                        endAngle: endAngle, clockwise: false)
                            path.closeSubpath()
                        }
                        .fill(isOutage ? outageColor : nonOutageColor)

                        // Label hours on even indices
                        if index % 2 == 0 {
                            let hour = index / 2
                            let numberAngle = Angle.degrees(Double(index) / 48.0 * 360.0 - 90)
                            let numberPosition = CGPoint(
                                x: center.x + radius * 0.85 * cos(CGFloat(numberAngle.radians)),
                                y: center.y + radius * 0.85 * sin(CGFloat(numberAngle.radians))
                            )

                            Text("\(hour)")
                                .font(.system(size: 10))
                                .position(numberPosition)
                                .foregroundColor(.black)
                        }
                    }

                    // Hour dividers
                    ForEach(0..<24) { hourMark in
                        let angle = Angle.degrees(Double(hourMark) / 24.0 * 360.0 - 90)
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: CGPoint(
                                x: center.x + radius * cos(CGFloat(angle.radians)),
                                y: center.y + radius * sin(CGFloat(angle.radians))
                            ))
                        }
                        .stroke(Color.black, lineWidth: 1)
                    }

                    // Half-hour dividers
                    ForEach(0..<48) { halfMark in
                        if halfMark % 2 != 0 {
                            let angle = Angle.degrees(Double(halfMark) / 48.0 * 360.0 - 90)
                            Path { path in
                                path.move(to: center)
                                path.addLine(to: CGPoint(
                                    x: center.x + radius * cos(CGFloat(angle.radians)),
                                    y: center.y + radius * sin(CGFloat(angle.radians))
                                ))
                            }
                            .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(Color.white)

            // Show total outage duration beneath the chart
            Text("Загальна тривалість: \(totalHours) год \(totalMinutes) хв")
                .font(.subheadline)
                .padding(.top, 10)

            // The button is only in the live view, not in the snapshot
            Button(action: shareClockImage) {
                Text("Share as PNG")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
        }
    }

    func timeInOutage(index: Int) -> Bool {
        let segmentMinutes = index * 30
        for time in outageTimes {
            guard let startHour = Int(time.start.prefix(2)),
                  let startMinute = Int(time.start.suffix(2)),
                  let endHour = Int(time.end.prefix(2)),
                  let endMinute = Int(time.end.suffix(2)) else {
                continue
            }

            let startTotal = startHour * 60 + startMinute
            let endTotal = endHour * 60 + endMinute

            if startTotal <= endTotal {
                if segmentMinutes >= startTotal && segmentMinutes < endTotal {
                    return true
                }
            } else {
                // wraps past midnight
                if segmentMinutes >= startTotal || segmentMinutes < endTotal {
                    return true
                }
            }
        }
        return false
    }

    func totalOutageDuration(outageTimes: [(start: String, end: String)]) -> (Int, Int) {
        var totalMinutes = 0
        for time in outageTimes {
            if let startHour = Int(time.start.prefix(2)),
               let startMinute = Int(time.start.suffix(2)),
               let endHour = Int(time.end.prefix(2)),
               let endMinute = Int(time.end.suffix(2)) {
                let startTotal = startHour * 60 + startMinute
                let endTotal = endHour * 60 + endMinute
                // If end < start, wrap around midnight scenario
                if endTotal >= startTotal {
                    totalMinutes += (endTotal - startTotal)
                } else {
                    // Wraps to next day
                    totalMinutes += ((24*60 - startTotal) + endTotal)
                }
            }
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return (hours, minutes)
    }

    func shareClockImage() {
        let size = CGSize(width: 300, height: 400) // Increased height to match snapshot changes
        // Use ClockSnapshotView instead of embedding ClockView again
        let snapshotView = ClockSnapshotView(
            cherga: cherga,
            subCherga: subCherga,
            outageTimes: outageTimes,
            caption: caption,
            nonOutageColor: nonOutageColor,
            outageColor: outageColor
        )

        let hostingController = UIHostingController(rootView: snapshotView)
        let tempWindow = UIWindow(frame: CGRect(origin: .zero, size: size))
        tempWindow.rootViewController = hostingController
        tempWindow.makeKeyAndVisible()
        hostingController.view.layoutIfNeeded()

        DispatchQueue.main.async {
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            if let context = UIGraphicsGetCurrentContext() {
                hostingController.view.layer.render(in: context)
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                self.generatedImage = image

                guard let imageToShare = self.generatedImage else { return }
                let activityVC = UIActivityViewController(activityItems: [imageToShare], applicationActivities: nil)

                if let rootVC = UIApplication.shared.windows.first?.rootViewController?.topmostViewController() {
                    activityVC.popoverPresentationController?.sourceView = rootVC.view
                    activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX,
                                                                                  y: rootVC.view.bounds.midY,
                                                                                  width: 0, height: 0)
                    activityVC.popoverPresentationController?.permittedArrowDirections = []
                    rootVC.present(activityVC, animated: true, completion: nil)
                }
            } else {
                UIGraphicsEndImageContext()
            }
        }
    }
}
