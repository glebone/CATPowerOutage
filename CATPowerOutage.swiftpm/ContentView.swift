import SwiftUI
import EventKit
import UIKit

struct ContentView: View {
    @State private var text: String = """
    ❗️ Черкащина. Маємо оновлену інформацію від енергетиків щодо графіків погодинних відключень електроенергії на сьогодні, 20 червня. Зверніть увагу: додано черги для знеструмленння. 
    
    Години без світла: 
    
    ■ 11:00-12:00  6 та 4 черги
    ■ 12:00-13:00  6 та 4 черги
    ■ 13:00-14:00  1 та 5 черги
    ■ 14:00-15:00  1 та 5 черги
    ■ 15:00-16:00  2 та 3 черги
    ■ 16:00-17:00  2 та 3 черги
    ■ 17:00-18:00  4 та 5 черги
    ■ 18:00-19:00  4 та 5 черги
    ■ 19:00-20:00  6 та 1 черги
    ■ 20:00-21:00  6 та 1 черги
    ■ 21:00-22:00  2 та 3 черги
    ■ 22:00-23:00  2 черга
    ■ 23:00-24:00  4 черга
    
    Telegram: 
    t.me/cherkaskaODA
    """
    
    @State private var selectedCherga: Int = UserDefaults.standard.integer(forKey: "selectedCherga") == 0 ? 3 : UserDefaults.standard.integer(forKey: "selectedCherga")
    @State private var showShareSheet = false
    @State private var iCalURL: URL?
    @State private var statusMessage: String?
    
    var body: some View {
        VStack {
            TextEditor(text: $text)
                .frame(height: 300)
                .padding()
                .border(Color.gray, width: 1)
            
            Picker("Select черга", selection: $selectedCherga) {
                ForEach(1..<7) { number in
                    Text("\(number)").tag(number)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedCherga) { value in
                UserDefaults.standard.set(value, forKey: "selectedCherga")
            }
            .padding()
            
            HStack {
                Button(action: { _ = createICalFile() }) {
                    Text("To iCal")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                
                Button(action: {
                    if createICalFile() {
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
    
    func createICalFile() -> Bool {
        guard let date = extractDate(from: text) else {
            statusMessage = "Failed to extract date from text."
            print("Failed to extract date from text.")
            return false
        }
        let pattern = try! NSRegularExpression(pattern: "■ (\\d{2}:\\d{2})-(\\d{2}:\\d{2}).*\\b\(selectedCherga)\\b", options: .caseInsensitive)
        let matches = pattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        let calendar = Calendar(identifier: .gregorian)
        
#if targetEnvironment(macCatalyst)
        // macOS (Catalyst) specific code: Generate iCal file
        var icsString = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Your Organization//Your Product//EN\n"
        
        for match in matches {
            let startRange = Range(match.range(at: 1), in: text)!
            let endRange = Range(match.range(at: 2), in: text)!
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
            \n
            """
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
#else
        // iOS specific code: Generate iCal file
        var icsString = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Your Organization//Your Product//EN\n"
        
        for match in matches {
            let startRange = Range(match.range(at: 1), in: text)!
            let endRange = Range(match.range(at: 2), in: text)!
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
            \n
            """
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
#endif
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
        components.year = 2024
        components.month = month
        components.day = day
        
        let extractedDate = Calendar(identifier: .gregorian).date(from: components)
        print("Extracted date: \(String(describing: extractedDate))")
        return extractedDate
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
