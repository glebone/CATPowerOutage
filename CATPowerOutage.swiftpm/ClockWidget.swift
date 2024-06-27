import SwiftUI

struct ClockView: View {
    var outageTimes: [(start: String, end: String)]
    var nonOutageColor: Color = .green
    var outageColor: Color = .red
    var caption: String
    
    @State private var showShareSheet = false
    @State private var generatedImage: UIImage? = nil
    
    var body: some View {
        VStack {
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
                    
                    ForEach(0..<24) { index in
                        let hour = index
                        let startAngle = Angle.degrees(Double(index) / 24.0 * 360.0 - 90)
                        let endAngle = Angle.degrees(Double(index + 1) / 24.0 * 360.0 - 90)
                        
                        Path { path in
                            path.move(to: center)
                            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                            path.closeSubpath()
                        }
                        .fill(hourInOutage(hour: hour) ? outageColor : nonOutageColor)
                        
                        // Add numbers
                        let numberAngle = Angle.degrees(Double(index) / 24.0 * 360.0 - 90)
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
            }
            .aspectRatio(1, contentMode: .fit)
            .background(Color.white) // Background color for the image
            
            Button(action: shareClockImage) {
                Text("Share as PNG")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
            .sheet(isPresented: $showShareSheet) {
                if let image = generatedImage {
                    ActivityView(activityItems: [image])
                }
            }
        }
    }
    
    func hourInOutage(hour: Int) -> Bool {
        for time in outageTimes {
            let startHour = Int(time.start.prefix(2))!
            let endHour = Int(time.end.prefix(2))!
            
            if startHour <= endHour {
                if hour >= startHour && hour < endHour {
                    return true
                }
            } else { // For cases where the outage spans midnight
                if hour >= startHour || hour < endHour {
                    return true
                }
            }
        }
        return false
    }
    
    func shareClockImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 340)) // Include space for caption
        let image = renderer.image { ctx in
            let hostingController = UIHostingController(rootView: VStack {
                Text(caption)
                    .font(.headline)
                    .padding(.bottom, 10)
                ClockView(outageTimes: outageTimes, nonOutageColor: nonOutageColor, outageColor: outageColor, caption: caption)
                    .frame(width: 300, height: 300)
            }.frame(width: 300, height: 340))
            hostingController.view.bounds = CGRect(x: 0, y: 0, width: 300, height: 340)
            hostingController.view.backgroundColor = .white
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
        
        generatedImage = image
        showShareSheet = true
    }
}



struct ClockView_Previews: PreviewProvider {
    static var previews: some View {
        ClockView(outageTimes: [("10:00", "12:00"), ("16:00", "18:00")], caption: "27 June")
            .frame(width: 300, height: 340)
    }
}
