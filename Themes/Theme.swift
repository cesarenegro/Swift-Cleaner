import SwiftUI

class Theme: ObservableObject {
    @Published var accentColor: Color = .blue
    @Published var sidebarBackground: Color = Color(red: 0.08, green: 0.10, blue: 0.15)
    @Published var useDarkMode: Bool = true
    
    static let shared = Theme()
    
    private init() {}
}