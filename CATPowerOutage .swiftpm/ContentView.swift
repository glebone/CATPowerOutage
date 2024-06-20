import SwiftUI
import EventKit

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
    
    var body: some View {
        VStack {
            TextEditor(text: $text)
                .frame(height: 300)
                .padding()
                .border(Color.gray, width: 1)
            
            Button(action: createICalFile) {
                Text("To iCal")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    
    func createICalFile() {
        let pattern = try! NSRegularExpression(pattern: "■ (\\d{2}:\\d{2})-(\\d{2}:\\d{2}).*(?:3 черга|3 черги|черга 3)", options: .caseInsensitive)
        let matches = pattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 20
        
        let eventStore = EKEventStore()
        
        eventStore.requestAccess(to: .event) { (granted, error) in
            if granted {
                for match in matches {
                    let startRange = Range(match.range(at: 1), in: text)!
                    let endRange = Range(match.range(at: 2), in: text)!
                    let startTime = String(text[startRange])
                    let endTime = String(text[endRange])
                    
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
                        print("Failed to save event with error : \(error)")
                    }
                }
                
                saveICal(events: matches, calendar: calendar)
            }
        }
    }
    
    func saveICal(events: [NSTextCheckingResult], calendar: Calendar) {
        var icsString = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Your Organization//Your Product//EN\n"
        
        for match in events {
            let startRange = Range(match.range(at: 1), in: text)!
            let endRange = Range(match.range(at: 2), in: text)!
            let startTime = String(text[startRange])
            let endTime = String(text[endRange])
            
            var components = DateComponents()
            components.year = 2024
            components.month = 6
            components.day = 20
            
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
        
        icsString += "END:VCALENDAR"
        
        if let data = icsString.data(using: .utf8) {
            let filename = getDocumentsDirectory().appendingPathComponent("power_outage_events.ics")
            try? data.write(to: filename)
            
            print("iCal file created at \(filename)")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
