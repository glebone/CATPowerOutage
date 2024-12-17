import SwiftUI
import EventKit
import UIKit

struct ContentView: View {
    @State private var text: String = """
    ❗️💡Черкащина. Відповідно до команди НЕК "Укренерго", у середу, 18 грудня, в області будуть застосовані графіки погодинних відключень електроенергії.

    Години без світла:

    ■ 1 черга (ІІ підчерга) 07:00-10:30
    ■ 2 черга (І підчерга) 17:30-20:00
    ■ 3 черга (ІІ підчерга) 10:30-14:00
    ■ 5 черга (ІІ підчерга) 14:00-17:30

    t.me/cherkaskaODA
    """
    
    @State private var selectedCherga: Int = UserDefaults.standard.integer(forKey: "selectedCherga") == 0 ? 1 : UserDefaults.standard.integer(forKey: "selectedCherga")
    @State private var selectedSubCherga: Int = UserDefaults.standard.integer(forKey: "selectedSubCherga") == 0 ? 1 : UserDefaults.standard.integer(forKey: "selectedSubCherga")
    @State private var showShareSheet = false
    @State private var iCalURL: URL?
    @State private var statusMessage: String?
    @State private var highlightText: Bool = false
    @State private var showClock = false
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.red)
                Text("Power Outages")
                    .bold()
                Image(systemName: "bolt.fill")
                    .foregroundColor(.red)
            }
            .padding(.top, 20)
            .font(.title)
            
            HStack {
                Button(action: selectAllText) {
                    Image(systemName: "selection.pin.in.out")
                }
                .padding(.trailing, 10)
                
                Button(action: pasteFromClipboard) {
                    Image(systemName: "doc.on.clipboard")
                }
                .padding(.trailing, 10)
                
                Button(action: {
                    showClock.toggle()
                }) {
                    Image(systemName: "clock.fill")
                }
                .padding(.trailing, 10)
            }
            .padding(.top, 10)
            
            TextEditor(text: $text)
                .frame(height: 300)
                .padding()
                .border(highlightText ? Color.blue : Color.gray, width: 1)
            
            if showClock {
                let caption = extractDateCaption(from: text) ?? "Unknown Date"
                ClockView(
                    cherga: selectedCherga,
                    subCherga: selectedSubCherga,
                    outageTimes: parseOutageTimes(from: text, for: selectedCherga, subCherga: selectedSubCherga),
                    caption: caption
                )
                .frame(height: 340)
                .padding()
            }
            
            // Main Черга picker
            Picker("Select черга", selection: $selectedCherga) {
                ForEach(1..<7) { number in
                    Text("\(number)").tag(number)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedCherga) {
                UserDefaults.standard.set(selectedCherga, forKey: "selectedCherga")
            }
            .padding()
            
            // Підчерга picker
            Picker("Select підчерга", selection: $selectedSubCherga) {
                Text("I").tag(1)
                Text("II").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedSubCherga) {
                UserDefaults.standard.set(selectedSubCherga, forKey: "selectedSubCherga")
            }
            .padding()
            
            HStack {
                Button(action: {
#if targetEnvironment(macCatalyst)
                    _ = generateICalFile()
#else
                    createEventsInCalendar()
#endif
                }) {
                    Text("To iCal")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                
                Button(action: {
                    if generateICalFile() {
                        showShareSheet.toggle()
                    }
                }) {
                    Text("Share iCal")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                .sheet(isPresented: $showShareSheet) {
                    if let iCalURL = iCalURL {
                        ActivityView(activityItems: [iCalURL])
                    } else {
                        Text("Failed to generate iCal file.")
                    }
                }
            }
            
            if let statusMessage = statusMessage {
                Text(statusMessage)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
    }
    
    func selectAllText() {
        highlightText = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            highlightText = false
        }
        print("Select All Text pressed")
    }
    
    func pasteFromClipboard() {
        if let clipboardText = UIPasteboard.general.string {
            text = clipboardText
        } else {
            statusMessage = "No text in clipboard."
        }
    }
    
    func createEventsInCalendar() {
        guard let date = extractDate(from: text) else {
            statusMessage = "Failed to extract date from text."
            print("Failed to extract date from text.")
            return
        }
        
        let subChergaPattern = (selectedSubCherga == 1) ? "І" : "ІІ"
        let pattern = "■\\s*(\\d+)\\s*черга\\s*\\(\(subChergaPattern)\\s*підчерга\\)\\s*(\\d{2}:\\d{2})-(\\d{2}:\\d{2})"
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        let calendar = Calendar(identifier: .gregorian)
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToEvents { granted, error in
            if granted {
                for match in matches {
                    guard let queueRange = Range(match.range(at: 1), in: text),
                          let startRange = Range(match.range(at: 2), in: text),
                          let endRange = Range(match.range(at: 3), in: text) else {
                        continue
                    }
                    
                    let foundQueue = Int(text[queueRange]) ?? 0
                    if foundQueue == self.selectedCherga {
                        let startTime = String(text[startRange])
                        let endTime = String(text[endRange])
                        
                        var components = calendar.dateComponents([.year, .month, .day], from: date)
                        components.hour = Int(startTime.prefix(2))
                        components.minute = Int(startTime.suffix(2))
                        let startDate = calendar.date(from: components)!
                        
                        components.hour = Int(endTime.prefix(2))
                        components.minute = Int(endTime.suffix(2))
                        let endDate = calendar.date(from: components)!
                        
                        let event = EKEvent(eventStore: eventStore)
                        event.title = "Power outage"
                        event.startDate = startDate
                        event.endDate = endDate
                        event.notes = "Power outage"
                        event.calendar = eventStore.defaultCalendarForNewEvents
                        
                        do {
                            try eventStore.save(event, span: .thisEvent)
                        } catch {
                            self.statusMessage = "Failed to save event with error: \(error)"
                            print("Failed to save event with error: \(error)")
                        }
                    }
                }
                self.statusMessage = "Events added to calendar"
            } else {
                self.statusMessage = "Access to calendar was denied."
                print("Access to calendar was denied.")
            }
        }
    }
    
    func generateICalFile() -> Bool {
        guard let date = extractDate(from: text) else {
            statusMessage = "Failed to extract date from text."
            print("Failed to extract date from text.")
            return false
        }
        
        let subChergaPattern = (selectedSubCherga == 1) ? "І" : "ІІ"
        let pattern = "■\\s*(\\d+)\\s*черга\\s*\\(\(subChergaPattern)\\s*підчерга\\)\\s*(\\d{2}:\\d{2})-(\\d{2}:\\d{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            print("Failed to create regex.")
            return false
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        let calendar = Calendar(identifier: .gregorian)
        var icsString = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Your Organization//Your Product//EN\n"
        
        for match in matches {
            guard let queueRange = Range(match.range(at: 1), in: text),
                  let startRange = Range(match.range(at: 2), in: text),
                  let endRange = Range(match.range(at: 3), in: text) else {
                continue
            }
            
            let foundQueue = Int(text[queueRange]) ?? 0
            if foundQueue == selectedCherga {
                let startTime = String(text[startRange])
                let endTime = String(text[endRange])
                
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = Int(startTime.prefix(2))
                components.minute = Int(startTime.suffix(2))
                let startDate = calendar.date(from: components)!
                
                components.hour = Int(endTime.prefix(2))
                components.minute = Int(endTime.suffix(2))
                let endDate = calendar.date(from: components)!
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                let startDateStr = dateFormatter.string(from: startDate)
                let endDateStr = dateFormatter.string(from: endDate)
                
                icsString += """
                BEGIN:VEVENT
                UID:\(UUID().uuidString)
                DTSTAMP:\(startDateStr)Z
                DTSTART:\(startDateStr)Z
                DTEND:\(endDateStr)Z
                SUMMARY:Power outage
                DESCRIPTION:Power outage
                END:VEVENT

                """
            }
        }
        
        icsString += "END:VCALENDAR"
        
        if let data = icsString.data(using: .utf8) {
            let filename = getDocumentsDirectory().appendingPathComponent("power_outage_events.ics")
            do {
                try data.write(to: filename)
                iCalURL = filename
                statusMessage = "iCal generated"
                print("iCal file created at \(filename)")
                return true
            } catch {
                statusMessage = "Failed to write iCal file."
                print("Failed to write iCal file: \(error)")
                return false
            }
        } else {
            statusMessage = "Failed to encode iCal data."
            print("Failed to encode iCal data.")
            return false
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func extractDate(from text: String) -> Date? {
        let months: [String: Int] = [
            "січня": 1,
            "лютого": 2,
            "березня": 3,
            "квітня": 4,
            "травня": 5,
            "червня": 6,
            "липня": 7,
            "серпня": 8,
            "вересня": 9,
            "жовтня": 10,
            "листопада": 11,
            "грудня": 12
        ]
        
        let pattern = "(\\d{1,2})\\s*(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            print("Failed to create regex.")
            return nil
        }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            print("No date match found in text.")
            return nil
        }
        
        let dayRange = Range(match.range(at: 1), in: text)!
        let monthRange = Range(match.range(at: 2), in: text)!
        
        guard let day = Int(text[dayRange]) else {
            print("Failed to extract day.")
            return nil
        }
        
        let monthName = String(text[monthRange]).lowercased()
        guard let month = months[monthName] else {
            print("Failed to extract month.")
            return nil
        }
        
        var components = DateComponents()
        components.year = 2024 // Adjust year if needed
        components.month = month
        components.day = day
        
        let extractedDate = Calendar(identifier: .gregorian).date(from: components)
        print("Extracted date: \(String(describing: extractedDate))")
        return extractedDate
    }
    
    func extractDateCaption(from text: String) -> String? {
        let months: [String: String] = [
            "січня": "January",
            "лютого": "February",
            "березня": "March",
            "квітня": "April",
            "травня": "May",
            "червня": "June",
            "липня": "July",
            "серпня": "August",
            "вересня": "September",
            "жовтня": "October",
            "листопада": "November",
            "грудня": "December"
        ]
        
        let pattern = "(\\d{1,2})\\s*(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            print("Failed to create regex.")
            return nil
        }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            print("No date match found in text.")
            return nil
        }
        
        let dayRange = Range(match.range(at: 1), in: text)!
        let monthRange = Range(match.range(at: 2), in: text)!
        
        guard let day = Int(text[dayRange]) else {
            print("Failed to extract day.")
            return nil
        }
        
        let monthName = String(text[monthRange]).lowercased()
        guard let month = months[monthName] else {
            print("Failed to extract month.")
            return nil
        }
        
        return "\(day) \(month)"
    }
    
    func parseOutageTimes(from text: String, for cherga: Int, subCherga: Int) -> [(start: String, end: String)] {
        let subChergaPattern = (subCherga == 1) ? "І" : "ІІ"
        let pattern = "■\\s*(\\d+)\\s*черга\\s*\\(\(subChergaPattern)\\s*підчерга\\)\\s*(\\d{2}:\\d{2})-(\\d{2}:\\d{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            print("Failed to create regex.")
            return []
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var times = [(start: String, end: String)]()
        
        for match in matches {
            guard let queueRange = Range(match.range(at: 1), in: text),
                  let startRange = Range(match.range(at: 2), in: text),
                  let endRange = Range(match.range(at: 3), in: text) else {
                continue
            }
            
            let foundQueue = Int(text[queueRange]) ?? 0
            if foundQueue == cherga {
                let startTime = String(text[startRange])
                let endTime = String(text[endRange])
                times.append((start: startTime, end: endTime))
            }
        }
        
        return times
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
