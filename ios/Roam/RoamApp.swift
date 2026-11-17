import SwiftUI
import MapKit
import PhotosUI
import CoreLocation
import UIKit
import CryptoKit
import AuthenticationServices
import Security


enum RoamStyle {
    static let canvas = Color(red: 0.985, green: 0.982, blue: 0.978)
    static let red = Color(red: 0.88, green: 0.10, blue: 0.19)
    static let surface = Color(red: 0.97, green: 0.97, blue: 0.98)
}
// A single continuous route, forming an R and a compass arrow.
struct RoamMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        p.move(to: point(0.26, 0.80)); p.addLine(to: point(0.26, 0.23))
        p.addLine(to: point(0.52, 0.23))
        p.addCurve(to: point(0.52, 0.55), control1: point(0.83, 0.23), control2: point(0.83, 0.55))
        p.addLine(to: point(0.26, 0.55)); p.move(to: point(0.48, 0.55)); p.addLine(to: point(0.76, 0.80))
        p.move(to: point(0.59, 0.79)); p.addLine(to: point(0.76, 0.80)); p.addLine(to: point(0.74, 0.63))
        return p
    }
}
// Secondary pages use quiet native navigation chrome.
struct RoamHeader: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26 draws the bar itself in Liquid Glass over the content.
            content.navigationBarTitleDisplayMode(.inline).toolbarColorScheme(.light, for: .navigationBar)
        } else {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.regularMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}
extension View { func roamHeader() -> some View { modifier(RoamHeader()) } }
struct DiscoveryArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var tilt: CGSize = .zero
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [Color(red: 1, green: 0.96, blue: 0.94), .white, Color(red: 0.98, green: 0.88, blue: 0.87)], startPoint: .topLeading, endPoint: .bottomTrailing)
                // Street grid gives depth without pretending to be a real map.
                ForEach(0..<7) { index in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.85))
                        .frame(width: 62, height: 120)
                        .rotationEffect(.degrees(-32))
                        .offset(x: CGFloat(index - 3) * 72, y: index.isMultiple(of: 2) ? -28 : 36)
                }
                route(g.size).stroke(RoamStyle.red.opacity(0.12), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                route(g.size).trim(from: 0, to: appeared ? 1 : 0)
                    .stroke(RoamStyle.red, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 7]))
                Circle().stroke(RoamStyle.red.opacity(appeared ? 0 : 0.25), lineWidth: 1)
                    .frame(width: 72).scaleEffect(reduceMotion ? 1 : appeared ? 1.8 : 0.8).offset(x: 45, y: -10)
                ZStack {
                    Circle().fill(.white).frame(width: 62).shadow(color: RoamStyle.red.opacity(0.2), radius: 18, y: 9)
                    Image(systemName: "location.north.fill").font(.system(size: 25, weight: .semibold)).foregroundStyle(RoamStyle.red).rotationEffect(.degrees(30))
                }.offset(x: 45, y: -10).offset(y: reduceMotion ? 0 : appeared ? -5 : 3)
                VStack(alignment: .leading) {
                    Label("IL TUO PROSSIMO WOW", systemImage: "sparkle").font(.system(size: 9, weight: .heavy)).tracking(1.5).padding(10).background(.white.opacity(0.85), in: Capsule())
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) { Text("Lasciati sorprendere.").font(.system(size: 21, weight: .bold)).tracking(-0.7); Text("La scoperta inizia da te.").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.headline).foregroundStyle(.white).frame(width: 38, height: 38).background(RoamStyle.red, in: Circle())
                    }
                }.padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.9), lineWidth: 1))
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(-tilt.height / 25)), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.width / 25)), axis: (x: 0, y: 1, z: 0))
            .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { tilt = CGSize(width: min(80, max(-80, $0.translation.width)), height: min(80, max(-80, $0.translation.height))) }.onEnded { _ in withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { tilt = .zero } })
            .onAppear {
                if reduceMotion { appeared = true }
                else { withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { appeared = true } }
            }
        }.frame(height: 214)
        .shadow(color: RoamStyle.red.opacity(0.09), radius: 20, y: 10)
        .accessibilityElement(children: .ignore).accessibilityLabel("Lasciati sorprendere. La scoperta inizia da te.")
    }
    private func route(_ size: CGSize) -> Path {
        Path { p in
            p.move(to: .init(x: -20, y: size.height * 0.6))
            p.addCurve(to: .init(x: size.width * 0.5 + 45, y: size.height * 0.5 - 10), control1: .init(x: size.width * 0.25, y: -20), control2: .init(x: size.width * 0.35, y: size.height * 0.8))
        }
    }
}
struct Place: Codable, Identifiable {
    let id, name, category: String
    let latitude, longitude: Double
    let description, symbol: String
    let distance: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
struct Trip: Codable, Identifiable {
    let id, destination, start_date, end_date, notes: String
}
struct WebPhoto: Decodable { let url, source_url, author, license, title: String; let provider: String? }
struct WebPhotoResponse: Decodable { let photo: WebPhoto?; let photos: [WebPhoto]? }
struct PlaceActivity: Decodable { let comments: Int; let rating: Double?; let photo: String? }
struct Review: Codable, Identifiable {
    let id, author, body: String
    let rating: Int
}
struct AuthorProfile: Decodable { let id, name, bio: String; let photo: String?; let is_demo: Int }
struct SocialPost: Decodable, Identifiable {
    let id, place_id, author, body, created_at: String
    let rating: Int
    var comments: Int
    let photo: String?
    var saved: Bool
    let mine: Bool
    let place: Place
    let author_profile: AuthorProfile?
    let is_demo: Bool?
    let author_key: String?
    var following: Bool?
}
struct CityResult: Equatable {
    let name: String
    let region, country: String?
    let coordinate: CLLocationCoordinate2D
    var id: String { "\(name)|\(Int(coordinate.latitude * 100))|\(Int(coordinate.longitude * 100))" }
    static func == (a: CityResult, b: CityResult) -> Bool { a.id == b.id }
}
struct GeocodeHit: Decodable {
    let name: String
    let region, country: String?
    let latitude, longitude: Double
}
struct GeocodeOutcome {
    var place: CityResult?
    var failure: String?
}
struct SocialFeedResponse: Decodable { let posts: [SocialPost]; let has_more: Bool }
struct SocialComment: Decodable, Identifiable {
    let id, author, body, created_at: String
    var author_photo: String? = nil
    var author_key: String? = nil
    var mine: Bool? = nil
}
struct SavedResponse: Decodable { let saved: Bool }
struct EmptyResponse: Decodable {}
struct Profile: Codable { var name = "Viaggiatore"; var bio = "Il prossimo viaggio inizia qui."; var photo: String? }
struct Stats: Codable {
    var comments = 0, posts = 0, places = 0, saved = 0, followers = 0, following = 0
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        followers = try c.decodeIfPresent(Int.self, forKey: .followers) ?? 0
        following = try c.decodeIfPresent(Int.self, forKey: .following) ?? 0
        comments = try c.decodeIfPresent(Int.self, forKey: .comments) ?? 0
        posts = try c.decodeIfPresent(Int.self, forKey: .posts) ?? 0
        places = try c.decodeIfPresent(Int.self, forKey: .places) ?? 0
        saved = try c.decodeIfPresent(Int.self, forKey: .saved) ?? 0
    }
}
/// A traveller: `u:<id>` for accounts, `n:<name>` for authors without an account, `roam` for the assistant.
struct Person: Decodable, Identifiable, Hashable {
    let key: String
    var name: String
    var photo: String?
    var bio = ""
    var posts = 0, places = 0, followers = 0, following = 0
    var mine = false, is_following = false, follows_you = false
    var has_account = false, is_roam = false, is_demo = false
    var id: String { key }
    init(key: String, name: String, photo: String? = nil) { self.key = key; self.name = name; self.photo = photo; has_account = key.hasPrefix("u:"); is_roam = key == "roam" }
    enum CodingKeys: String, CodingKey { case key, name, photo, bio, posts, places, followers, following, mine, is_following, follows_you, has_account, is_roam, is_demo }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? "n:" + name
        photo = try c.decodeIfPresent(String.self, forKey: .photo)
        bio = try c.decodeIfPresent(String.self, forKey: .bio) ?? ""
        posts = try c.decodeIfPresent(Int.self, forKey: .posts) ?? 0
        places = try c.decodeIfPresent(Int.self, forKey: .places) ?? 0
        followers = try c.decodeIfPresent(Int.self, forKey: .followers) ?? 0
        following = try c.decodeIfPresent(Int.self, forKey: .following) ?? 0
        mine = try c.decodeIfPresent(Bool.self, forKey: .mine) ?? false
        is_following = try c.decodeIfPresent(Bool.self, forKey: .is_following) ?? false
        follows_you = try c.decodeIfPresent(Bool.self, forKey: .follows_you) ?? false
        has_account = try c.decodeIfPresent(Bool.self, forKey: .has_account) ?? key.hasPrefix("u:")
        is_roam = try c.decodeIfPresent(Bool.self, forKey: .is_roam) ?? false
        is_demo = try c.decodeIfPresent(Bool.self, forKey: .is_demo) ?? false
    }
    static func == (a: Person, b: Person) -> Bool { a.key == b.key }
    func hash(into h: inout Hasher) { h.combine(key) }
}
struct ChatReply: Decodable { let reply: String; let places: [Place]?; let posts: [SocialPost]? }
struct TravelPreferences: Codable, Equatable {
    var travel_style = ""; var pace = ""; var budget = ""; var companions = ""
    var interests: [String] = []; var dietary = ""; var notes = ""
    var onboarded: Bool? = nil
}
struct AIMemory: Decodable { let summary: String; let events: Int }
struct AuthUser: Decodable { let id: Int; let name: String; let email: String?; let providers: [String]; let onboarded: Bool }
struct AuthSessionResponse: Decodable { let token: String; let user: AuthUser }
struct AuthConfig: Decodable { let google_client_id: String?; let apple: Bool }

/// The session token lives in the Keychain, never in UserDefaults.
enum Keychain {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "it.robertolibanora.roam", kSecAttrAccount as String: "session"]
    static var token: String? {
        get {
            var item: CFTypeRef?
            var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
            guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(query as CFDictionary)
            guard let newValue, let data = newValue.data(using: .utf8) else { return }
            var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(q as CFDictionary, nil)
        }
    }
}
struct WeatherResponse: Decodable { let current: Current; struct Current: Decodable { let temperature_2m: Double; let weather_code: Int } }
struct Message: Identifiable { var id = UUID().uuidString; let text: String; let user: Bool; var places: [Place] = []; var posts: [SocialPost] = [] }

@MainActor final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var city = "La tua zona"
    @Published var status = "Attiva la posizione"
    @Published var permissionDenied = false
    @Published var weather = "Meteo in attesa della posizione"
    func refreshWeather() async {
        guard let c = coordinate else { weather = "Meteo in attesa della posizione"; return }
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(c.latitude)&longitude=\(c.longitude)&current=temperature_2m,weather_code") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let current = try JSONDecoder().decode(WeatherResponse.self, from: data).current
            let condition = current.weather_code == 0 ? "Sereno" : current.weather_code <= 3 ? "Nuvoloso" : current.weather_code <= 48 ? "Nebbia" : current.weather_code >= 95 ? "Temporali" : "Precipitazioni"
            weather = "\(Int(current.temperature_2m.rounded()))° · \(condition)"
        } catch { weather = "Meteo non disponibile" }
    }
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func request() {
        guard CLLocationManager.locationServicesEnabled() else { status = "Abilita Localizzazione nelle Impostazioni"; permissionDenied = true; return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: status = "Cerco la tua posizione…"; permissionDenied = false; manager.requestLocation()
        case .denied, .restricted: status = "Consenti la posizione nelle Impostazioni"; permissionDenied = true
        @unknown default: break
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { status = "Consenti la posizione nelle Impostazioni"; permissionDenied = true; coordinate = nil; city = "La tua zona"; weather = "Meteo in attesa della posizione" }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0, abs(location.timestamp.timeIntervalSinceNow) < 120 else { return }
        coordinate = location.coordinate; status = "Posizione attuale"
        Task { await refreshWeather() }
        CLGeocoder().reverseGeocodeLocation(location) { marks, _ in
            Task { @MainActor in self.city = marks?.first?.locality ?? "Vicino a te" }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { status = "Posizione non disponibile. Riprova all’aperto." }
}

@MainActor final class Store: ObservableObject {
    @Published var places: [Place] = []
    @Published var mapAreaPlaces: [Place]?
    @Published var socialPosts: [SocialPost] = []
    @Published var socialLoading = false
    @Published var socialError: String?
    @Published var socialHasMore = false
    @Published var myPosts: [SocialPost] = []
    @Published var myPostsLoaded = false
    @Published var myPostsError: String?
    @Published var personFeed: [SocialPost] = []
    @Published var conversations: [Conversation] = []
    @Published var groups: [TripGroup] = []
    @Published var unreadChats = 0
    private var socialRequestID = UUID()
    @Published var webPhotos: [String: WebPhoto] = [:]
    @Published var placePosts: [String: [SocialPost]] = [:]
    private var webPhotoChecked = Set<String>()
    private var photoAlternatives: [String: [WebPhoto]] = [:]
    @Published var activity: [String: PlaceActivity] = [:]
    @Published var trips: [Trip] = []
    @Published var profile = Profile()
    @Published var stats = Stats()
    @Published var error: String?
    @Published var loading = false
    private var placesRequestID = UUID()
    @Published var placesError: String?
    @Published var accountError: String?
    @Published var preferences: TravelPreferences?
    @Published var needsOnboarding = false
    @Published var token: String? = Keychain.token
    @Published var user: AuthUser?
    @Published var source = "OpenStreetMap"
    @AppStorage("appleSearchEnabled") var appleSearchEnabled = true
    @AppStorage("viewportSearchEnabled") var viewportSearchEnabled = true
    @AppStorage("apiURL") var apiURL = "http://100.90.158.14:8000"
    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: apiURL + path), ["http", "https"].contains(url.scheme ?? "") else { throw URLError(.badURL) }
        var request = authorized(url, method: method); request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.timeoutInterval = path == "/chat" ? 100 : path.hasSuffix("/plan") ? 200 : 65
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401, token != nil, !path.hasPrefix("/auth/") { signOut(callServer: false) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw NSError(domain: "API", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: detail ?? "Server non disponibile. Controlla la connessione."])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func authorized(_ url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url); request.httpMethod = method
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        return request
    }
    func signedIn(_ session: AuthSessionResponse) {
        Keychain.token = session.token; token = session.token; user = session.user
        preferences = nil; needsOnboarding = !session.user.onboarded
    }
    func signOut(callServer: Bool = true) {
        if callServer, let url = URL(string: apiURL + "/auth/logout") {
            let request = authorized(url, method: "POST")
            Task { _ = try? await URLSession.shared.data(for: request) }
        }
        Keychain.token = nil; token = nil; user = nil
        // Nothing from the previous account may remain on screen.
        trips = []; personFeed = []; profile = Profile(); stats = Stats(); preferences = nil; needsOnboarding = false
        socialPosts = []; myPosts = []; myPostsLoaded = false; activity = [:]; conversations = []; unreadChats = 0
    }
    func load(_ coordinate: CLLocationCoordinate2D?) async {
        async let account: () = loadAccount()
        await loadPlaces(coordinate)
        await account
    }
    private func loadAccount() async {
        guard token != nil else { return }
        if user == nil { user = try? await request("/auth/me") }
        do {
            trips = try await request("/trips")
            profile = try await request("/profile")
            stats = try await request("/stats")
            accountError = nil
        } catch { if !Task.isCancelled { accountError = "Viaggi e profilo non sincronizzati. Controlla Tailscale e il backend." } }
        if preferences == nil, let loaded: TravelPreferences = try? await request("/me/preferences") {
            preferences = loaded; needsOnboarding = loaded.onboarded != true
        }
    }
    func savePreferences(_ value: TravelPreferences) async throws {
        preferences = try await request("/me/preferences", method: "PUT", body: JSONEncoder().encode(value))
        needsOnboarding = false
    }
    /// Teaches the assistant what the user looks at; failures are silent by design.
    func track(view place: Place) {
        Task {
            guard let body = try? JSONSerialization.data(withJSONObject: ["kind": "view_place", "place_id": place.id]) else { return }
            let _: EmptyResponse? = try? await request("/me/events", method: "POST", body: body)
        }
    }
    func loadPlaces(_ coordinate: CLLocationCoordinate2D?) async {
        let requestID = UUID(); placesRequestID = requestID
        loading = true; placesError = nil
        defer { if placesRequestID == requestID { loading = false } }
        guard let c = coordinate else { places = []; return }
        do {
            if appleSearchEnabled {
                let (loaded, partial) = try await searchApple(c) { updated in
                    guard self.placesRequestID == requestID else { return }
                    self.places = updated; self.source = "Mappe Apple"
                }
                guard placesRequestID == requestID else { return }
                places = loaded; source = "Mappe Apple"
                if partial { placesError = "Alcune categorie non sono disponibili. Puoi riprovare." }
            }
            else {
                source = "OpenStreetMap"
                let loaded: [Place] = try await request("/places?latitude=\(c.latitude)&longitude=\(c.longitude)")
                try Task.checkCancellation()
                guard placesRequestID == requestID else { return }
                places = loaded
            }
        } catch {
            if !Task.isCancelled && placesRequestID == requestID {
                placesError = appleSearchEnabled ? "Mappe Apple non risponde. Controlla Internet e riprova." : "OpenStreetMap non è disponibile. Riprova o cerca con Mappe Apple."
            }
        }
    }
    private let discoveryQueries: [(String, String, String)] = [
        ("attrazioni turistiche", "Attrazione", "building.columns.fill"),
        ("musei", "Attrazione", "building.columns.fill"),
        ("parchi e giardini", "Parco", "leaf.fill"),
        ("ristoranti", "Ristorante", "fork.knife"),
        ("caffè", "Caffè", "cup.and.saucer.fill"),
        ("negozi", "Negozio", "bag.fill"),
        ("monumenti e siti storici", "Attrazione", "building.columns.fill"),
        ("punti panoramici", "Attrazione", "building.columns.fill"),
        ("gallerie d’arte", "Attrazione", "building.columns.fill"),
        ("pizzerie", "Ristorante", "fork.knife"),
        ("gelaterie e pasticcerie", "Caffè", "cup.and.saucer.fill"),
        ("librerie e mercati", "Negozio", "bag.fill")
    ]
    private func searchApple(_ coordinate: CLLocationCoordinate2D, onUpdate: ([Place]) -> Void) async throws -> ([Place], Bool) {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var results: [String: Place] = [:]
        var lastError: Error?
        for (query, category, symbol) in discoveryQueries {
            try Task.checkCancellation()
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = query
            req.resultTypes = .pointOfInterest
            req.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 10000, longitudinalMeters: 10000)
            do {
                let response = try await MKLocalSearch(request: req).start()
                for item in response.mapItems {
                    guard let name = item.name, let location = item.placemark.location else { continue }
                    let distance = origin.distance(from: location) / 1000
                    guard distance <= 5 else { continue }
                    let c = location.coordinate
                    let identity = "\(name.lowercased())|\(String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), c.latitude))|\(String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), c.longitude))"
                    let id = "apple-" + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
                    if results[id] == nil {
                        let address = [item.placemark.thoroughfare, item.placemark.subThoroughfare, item.placemark.locality].compactMap { $0 }.joined(separator: " ")
                        results[id] = Place(id: id, name: name, category: category, latitude: c.latitude, longitude: c.longitude, description: address.isEmpty ? "Luogo trovato con Mappe Apple. Verifica gli orari prima di partire." : address, symbol: symbol, distance: distance)
                    }
                }
                try Task.checkCancellation()
                onUpdate(results.values.sorted { $0.distance < $1.distance })
            } catch { try Task.checkCancellation(); lastError = error }
        }
        try Task.checkCancellation()
        if results.isEmpty, let lastError { throw lastError }
        return (results.values.sorted { $0.distance < $1.distance }, lastError != nil)
    }
    func register(_ place: Place) async throws {
        if place.id.hasPrefix("apple-") || place.id.hasPrefix("landmark-") {
            let _: Place = try await request("/places/register", method: "POST", body: JSONEncoder().encode(place))
        }
    }
    func loadWebPhoto(_ place: Place) async {
        guard !webPhotoChecked.contains(place.id) else { return }
        webPhotoChecked.insert(place.id)
        do {
            try await register(place)
            let result: WebPhotoResponse = try await request("/places/\(place.id)/web-image")
            if let photo = result.photo {
                webPhotos[place.id] = photo
                photoAlternatives[place.id] = (result.photos ?? []).filter { $0.url != photo.url }
            }
        } catch { webPhotoChecked.remove(place.id) }
    }
    // Community posts of one place, used as photos when the web has none.
    func loadPlacePosts(_ place: Place) async {
        guard placePosts[place.id] == nil else { return }
        do {
            let payload = try JSONSerialization.data(withJSONObject: ["place_ids": [place.id], "saved_only": false, "following_only": false, "offset": 0])
            let result: SocialFeedResponse = try await request("/feed/query", method: "POST", body: payload)
            placePosts[place.id] = result.posts
        } catch {}
    }
    // City results arrive in two steps: Apple Maps first (fast), then OpenStreetMap via the backend (richer, slower).
    func cityBackendPlaces(_ city: CityResult) async -> [Place] {
        let c = city.coordinate
        return ((try? await request("/places?latitude=\(c.latitude)&longitude=\(c.longitude)") as [Place]) ?? []).filter { $0.distance <= 8 }
    }
    func cityMapsPlaces(_ city: CityResult) async -> [Place] {
        appleSearchEnabled ? await cityApplePlaces(city.coordinate).filter { $0.distance <= 8 } : []
    }
    func cityPosts(_ places: [Place]) async -> [SocialPost] {
        guard !places.isEmpty, let payload = try? JSONSerialization.data(withJSONObject: ["place_ids": Array(places.map(\.id).prefix(500)), "saved_only": false, "following_only": false, "offset": 0]) else { return [] }
        return (try? await request("/feed/query", method: "POST", body: payload) as SocialFeedResponse)?.posts ?? []
    }
    func cityApplePlaces(_ c: CLLocationCoordinate2D) async -> [Place] {
        let queries = [("attrazioni turistiche", "Attrazione"), ("musei", "Attrazione"), ("monumenti", "Attrazione"), ("ristoranti", "Ristorante"), ("caffè", "Caffè"), ("parchi", "Parco"), ("negozi", "Negozio")]
        return await withTaskGroup(of: [Place].self) { group in
            for (query, category) in queries { group.addTask { (try? await self.searchPlaces(query, near: c, category: category)) ?? [] } }
            var all: [Place] = []
            for await found in group { all += found }
            return all
        }
    }
    func communityPhotos(_ placeID: String) -> [SocialPost] {
        var seen = Set<String>()
        return ((placePosts[placeID] ?? []) + socialPosts + myPosts + personFeed)
            .filter { $0.place_id == placeID && $0.photo != nil && seen.insert($0.id).inserted }
    }
    func nextWebPhoto(_ place: Place) -> Bool {
        guard var alternatives = photoAlternatives[place.id], !alternatives.isEmpty else { return false }
        webPhotos[place.id] = alternatives.removeFirst()
        photoAlternatives[place.id] = alternatives
        return true
    }
    func searchViewport(_ region: MKCoordinateRegion, origin: CLLocationCoordinate2D, onUpdate: (([Place]) -> Void)? = nil) async throws -> [Place] {
        guard viewportSearchEnabled else { return [] }
        let originLocation=CLLocation(latitude:origin.latitude,longitude:origin.longitude)
        let span=MKCoordinateSpan(latitudeDelta:min(2,max(0.01,region.span.latitudeDelta)),longitudeDelta:min(3,max(0.01,region.span.longitudeDelta)))
        let wide=span.latitudeDelta > 0.08 || span.longitudeDelta > 0.12
        let offsets: [(Double,Double)] = wide ? [(-0.25,-0.25),(-0.25,0.25),(0.25,-0.25),(0.25,0.25)] : [(0,0)]
        var results:[String:Place]=[:]
        var failures=0
        for offset in offsets {
            for (query,category,symbol) in (wide ? Array(discoveryQueries.prefix(6)) : discoveryQueries) {
                try Task.checkCancellation()
                let req=MKLocalSearch.Request();req.naturalLanguageQuery=query;req.resultTypes = .pointOfInterest
                req.region=MKCoordinateRegion(center:CLLocationCoordinate2D(latitude:max(-85,min(85,region.center.latitude+span.latitudeDelta*offset.0)),longitude:wrapLongitude(region.center.longitude+span.longitudeDelta*offset.1)),span:MKCoordinateSpan(latitudeDelta:span.latitudeDelta/(wide ? 2 : 1),longitudeDelta:span.longitudeDelta/(wide ? 2 : 1)))
                let search=MKLocalSearch(request:req)
                do {
                    let response = try await withTaskCancellationHandler { try await search.start() } onCancel: { Task { @MainActor in search.cancel() } }
                    for item in response.mapItems {
                        guard let name=item.name,let location=item.placemark.location else { continue }
                        let c=location.coordinate
                        let lonDelta=abs(wrapLongitude(c.longitude-region.center.longitude))
                        guard abs(c.latitude-region.center.latitude)<=region.span.latitudeDelta/2,lonDelta<=region.span.longitudeDelta/2 else { continue }
                        let identity="\(name.lowercased())|\(String(format:"%.5f",locale:Locale(identifier:"en_US_POSIX"),c.latitude))|\(String(format:"%.5f",locale:Locale(identifier:"en_US_POSIX"),c.longitude))"
                        let id="apple-"+SHA256.hash(data:Data(identity.utf8)).map { String(format:"%02x",$0) }.joined()
                        let address=[item.placemark.thoroughfare,item.placemark.locality].compactMap{$0}.joined(separator:" ")
                        if results[id] == nil { results[id]=Place(id:id,name:name,category:category,latitude:c.latitude,longitude:c.longitude,description:address.isEmpty ? "Luogo trovato con Mappe Apple." : address,symbol:symbol,distance:originLocation.distance(from:location)/1000) }
                    }
                    try Task.checkCancellation()
                    onUpdate?(Array(results.values))
                } catch { try Task.checkCancellation(); failures += 1 }
            }
        }
        if results.isEmpty && failures>0 { throw URLError(.cannotLoadFromNetwork) }
        try Task.checkCancellation()
        if places.isEmpty && originLocation.distance(from:CLLocation(latitude:region.center.latitude,longitude:region.center.longitude)) < 5000 {
            places=results.values.filter{$0.distance <= 5}.sorted{$0.distance < $1.distance}
            if !places.isEmpty { source="Mappe Apple" }
        }
        return Array(results.values)
    }
    func loadSocialFeed(ids: [String], savedOnly: Bool, following: Bool = false, append: Bool = false) async {
        let token = UUID(); socialRequestID = token
        socialLoading = true; socialError = nil
        let offset = append ? (savedOnly ? socialPosts.filter { $0.saved }.count : socialPosts.count) : 0
        if !append {
            let requested = Set(ids.prefix(500))
            socialPosts = socialPosts.filter { following ? ($0.following == true || $0.mine) : savedOnly ? $0.saved : requested.contains($0.place_id) }
            socialHasMore = false
        }
        defer { if socialRequestID == token { socialLoading = false } }
        do {
            let payload = try JSONSerialization.data(withJSONObject: ["place_ids": following ? [] : Array(ids.prefix(500)), "saved_only": savedOnly, "following_only": following, "offset": offset])
            let result: SocialFeedResponse = try await request("/feed/query", method: "POST", body: payload)
            try Task.checkCancellation()
            guard token == socialRequestID else { return }
            socialPosts = append ? socialPosts + result.posts : result.posts
            socialHasMore = result.has_more
        } catch { if !Task.isCancelled && token == socialRequestID { socialError = "Feed non sincronizzato. Controlla la connessione e riprova." } }
    }
    func toggleSaved(_ post: SocialPost) async {
        do {
            let payload = try JSONSerialization.data(withJSONObject: ["saved": !post.saved])
            let result: SavedResponse = try await request("/feed/posts/\(post.id)/saved", method: "PUT", body: payload)
            if result.saved != post.saved { stats.saved = max(0, stats.saved + (result.saved ? 1 : -1)) }
            updatePost(post.id) { $0.saved = result.saved }
        } catch { self.error = "Salvataggio non riuscito. Riprova." }
    }
    // Feed and profile hold separate copies of the same post; keep both in sync.
    func updatePost(_ id: String, _ change: (inout SocialPost) -> Void) {
        if let index = socialPosts.firstIndex(where: { $0.id == id }) { change(&socialPosts[index]) }
        if let index = myPosts.firstIndex(where: { $0.id == id }) { change(&myPosts[index]) }
        if let index = personFeed.firstIndex(where: { $0.id == id }) { change(&personFeed[index]) }
    }
    // Free-text Apple Maps search used by Cerca; only runs when the user opted in to Apple search.
    func searchPlaces(_ query: String, near coordinate: CLLocationCoordinate2D, category fallback: String? = nil) async throws -> [Place] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.resultTypes = .pointOfInterest
        req.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 20000, longitudinalMeters: 20000)
        let search = MKLocalSearch(request: req)
        let response = try await withTaskCancellationHandler { try await search.start() } onCancel: { Task { @MainActor in search.cancel() } }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return response.mapItems.compactMap { item -> Place? in
            guard let name = item.name, let location = item.placemark.location else { return nil }
            let c = location.coordinate
            let identity = "\(name.lowercased())|\(String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), c.latitude))|\(String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), c.longitude))"
            let id = "apple-" + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
            let category: String
            switch item.pointOfInterestCategory {
            case .some(.park), .some(.nationalPark), .some(.beach): category = "Parco"
            case .some(.restaurant), .some(.foodMarket), .some(.winery), .some(.brewery): category = "Ristorante"
            case .some(.cafe), .some(.bakery): category = "Caffè"
            case .some(.store): category = "Negozio"
            case .some(.museum), .some(.theater), .some(.library), .some(.university): category = "Attrazione"
            default: category = fallback ?? "Attrazione"
            }
            let symbol = ["Parco": "leaf.fill", "Ristorante": "fork.knife", "Caffè": "cup.and.saucer.fill", "Negozio": "bag.fill"][category] ?? "building.columns.fill"
            let address = [item.placemark.thoroughfare, item.placemark.subThoroughfare, item.placemark.locality].compactMap { $0 }.joined(separator: " ")
            return Place(id: id, name: name, category: category, latitude: c.latitude, longitude: c.longitude, description: address.isEmpty ? "Luogo trovato con Mappe Apple." : address, symbol: symbol, distance: origin.distance(from: location) / 1000)
        }.sorted { $0.distance < $1.distance }
    }
    private func queryValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#"))) ?? ""
    }
    func searchPeople(_ query: String) async throws -> [Person] { try await request("/people?q=" + queryValue(query)) }
    func loadPersonFeed(_ person: Person) async throws {
        let result: SocialFeedResponse = try await request("/people/posts?key=" + queryValue(person.key))
        personFeed = result.posts
    }
    func profile(of key: String) async throws -> Person { try await request("/people/profile?key=" + queryValue(key)) }
    /// Follow or unfollow; every copy of that author's posts updates its "Segui" button.
    func setFollowing(_ key: String, _ follow: Bool) async throws -> Person {
        let body = try JSONSerialization.data(withJSONObject: ["key": key, "follow": follow])
        let person: Person = try await request("/people/follow", method: "PUT", body: body)
        for list in [\Store.socialPosts, \Store.myPosts, \Store.personFeed] as [ReferenceWritableKeyPath<Store, [SocialPost]>] {
            for i in self[keyPath: list].indices where self[keyPath: list][i].author_key == key { self[keyPath: list][i].following = person.is_following }
        }
        if let stats: Stats = try? await request("/stats") { self.stats = stats }
        return person
    }
    func connections(of key: String, kind: String) async throws -> [Person] { try await request("/people/connections?key=" + queryValue(key) + "&kind=" + kind) }
    func loadConversations() async {
        guard token != nil, let list: [Conversation] = try? await request("/dm/conversations") else { return }
        conversations = list; unreadChats = list.filter { $0.unread > 0 }.count + groups.filter { $0.unread > 0 }.count
    }
    func loadGroups() async {
        guard token != nil, let list: [TripGroup] = try? await request("/groups") else { return }
        groups = list; unreadChats = conversations.filter { $0.unread > 0 }.count + list.filter { $0.unread > 0 }.count
    }
    // Towns, regions, islands and countries. Italian names are resolved on the backend
    // (Tokyo is a prefecture, Spagna a country). Apple is only a fallback when that
    // service cannot be reached, so a phone in Italy does not turn Spagna into Piazza di Spagna.
    func geocodeOutcome(_ text: String) async -> GeocodeOutcome {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return GeocodeOutcome() }
        do {
            return GeocodeOutcome(place: try await geocodeOnServer(query))
        } catch let error as NSError where error.domain == "API" && (error.code == 404 || error.code == 422) {
            return GeocodeOutcome()
        } catch let error as NSError where error.domain == "API" {
            // A definitive server answer (the country is known but its capital is not, or the geocoder is down)
            // must not fall through to Apple: near Italy, "Spagna" becomes Piazza di Spagna.
            return GeocodeOutcome(failure: error.localizedDescription)
        } catch {
            if let apple = await appleGeocode(query) { return GeocodeOutcome(place: apple) }
            return GeocodeOutcome(failure: "Ricerca destinazioni non disponibile. Controlla la connessione.")
        }
    }
    private func geocodeOnServer(_ text: String) async throws -> CityResult {
        let hit: GeocodeHit = try await request("/geocode?q=" + queryValue(text))
        return CityResult(name: hit.name, region: blankToNil(hit.region), country: blankToNil(hit.country), coordinate: .init(latitude: hit.latitude, longitude: hit.longitude))
    }
    private func blankToNil(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    /// Used only when the backend cannot be reached. Matches the query against the city,
    /// the prefecture (Tokyo) and the country (Spagna), and prefers that hit over the first
    /// result, which location bias often pins to somewhere in Italy.
    private func appleGeocode(_ text: String) async -> CityResult? {
        let locale = Locale(identifier: "it_IT")
        let fold: (String) -> String = { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale) }
        let wanted = fold(text)
        guard let marks = try? await CLGeocoder().geocodeAddressString(text, in: nil, preferredLocale: locale) else { return nil }
        func labels(_ mark: CLPlacemark) -> [String] {
            var values: [String?] = [mark.locality, mark.subLocality, mark.subAdministrativeArea, mark.administrativeArea, mark.country, mark.name, mark.inlandWater, mark.ocean]
            values.append(contentsOf: mark.areasOfInterest ?? [])
            return values.compactMap { $0 }.map(fold)
        }
        func score(_ mark: CLPlacemark) -> Int {
            let names = labels(mark)
            guard names.contains(where: { $0 == wanted || $0.hasPrefix(wanted) || ($0.count >= 4 && wanted.hasPrefix($0)) }) else { return 0 }
            if fold(mark.country ?? "") == wanted { return 100 }
            if fold(mark.locality ?? "") == wanted { return 90 }
            if fold(mark.administrativeArea ?? "") == wanted { return 85 }
            if fold(mark.name ?? "") == wanted { return 70 }
            return names.contains(wanted) ? 60 : 30
        }
        let ranked = marks.compactMap { mark -> (Int, CLPlacemark)? in
            guard mark.location != nil else { return nil }
            let value = score(mark)
            return value > 0 ? (value, mark) : nil
        }
        guard let mark = ranked.max(by: { $0.0 < $1.0 })?.1, let coordinate = mark.location?.coordinate else { return nil }
        let display = [mark.locality, mark.administrativeArea, mark.name, mark.country, mark.inlandWater].compactMap { $0 }.first { name in
            let folded = fold(name)
            return folded == wanted || folded.hasPrefix(wanted) || (folded.count >= 4 && wanted.hasPrefix(folded))
        } ?? text
        return CityResult(name: display, region: mark.locality == nil ? nil : mark.administrativeArea, country: mark.country, coordinate: coordinate)
    }
    func refreshUnread() async {
        guard token != nil, let result: UnreadResponse = try? await request("/dm/unread") else { return }
        unreadChats = result.count
    }
    func openConversation(with key: String) async throws -> Conversation {
        let body = try JSONSerialization.data(withJSONObject: ["key": key])
        return try await request("/dm/conversations", method: "POST", body: body)
    }
    @discardableResult func sendMessage(_ conversation: String, body text: String = "", post: String? = nil) async throws -> DirectMessage {
        var payload: [String: Any] = ["body": text]; if let post { payload["post_id"] = post }
        return try await request("/dm/conversations/\(conversation)/messages", method: "POST", body: try JSONSerialization.data(withJSONObject: payload))
    }
    // Places a post can be tied to: nearby results plus the last explored map area.
    var knownPlaces: [Place] {
        var seen = Set<String>()
        return (places + (mapAreaPlaces ?? [])).filter { seen.insert($0.id).inserted }.sorted { $0.distance < $1.distance }
    }
    func loadMyPosts() async {
        do {
            let result: SocialFeedResponse = try await request("/feed/mine")
            myPosts = result.posts; myPostsLoaded = true; myPostsError = nil
        } catch { if !Task.isCancelled { myPostsError = "I tuoi post non sono sincronizzati. Riprova." } }
    }
    func published(_ post: SocialPost) {
        myPosts.insert(post, at: 0); stats.posts += 1
    }
    func deletePost(_ post: SocialPost) async -> Bool {
        do {
            guard let url = URL(string: apiURL + "/feed/posts/" + post.id) else { throw URLError(.badURL) }
            let req = authorized(url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 204 else { throw URLError(.badServerResponse) }
            socialPosts.removeAll { $0.id == post.id }; myPosts.removeAll { $0.id == post.id }; personFeed.removeAll { $0.id == post.id }
            stats.posts = max(0, stats.posts - 1)
            return true
        } catch { self.error = "Eliminazione non riuscita. Riprova."; return false }
    }
    private func wrapLongitude(_ value: Double) -> Double { let v=(value+180).truncatingRemainder(dividingBy:360);return (v<0 ? v+360 : v)-180 }
    func refreshActivity(_ place: Place) async {
        do {
            try await register(place)
            let value: PlaceActivity = try await request("/places/\(place.id)/activity")
            activity[place.id] = value
        } catch { }
    }
    func deleteTrip(_ trip: Trip) async {
        do {
            guard let url = URL(string: apiURL + "/trips/" + trip.id) else { throw URLError(.badURL) }
            let req = authorized(url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 204 else { throw URLError(.badServerResponse) }
            trips.removeAll { $0.id == trip.id }; stats = try await request("/stats")
        } catch { self.error = error.localizedDescription }
    }
}

@main struct RoamApp: App {
    @StateObject private var store = Store()
    @StateObject private var location = LocationService()
    init() {
        // Apple Maps search is on by default (OpenStreetMap's public servers are often saturated).
        // One-time switch for installs that stored the old "off" default; the toggle in Settings still wins afterwards.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "appleSearchDefaultOnApplied") {
            defaults.set(true, forKey: "appleSearchEnabled"); defaults.set(true, forKey: "appleSearchDefaultOnApplied")
        }
        // One light native appearance for standard, scroll-edge and compact navigation.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.preferredFont(forTextStyle: .headline)
        ]
        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.compactScrollEdgeAppearance = appearance
        navigationBar.tintColor = UIColor(RoamStyle.red)
        navigationBar.prefersLargeTitles = false
    }
    var body: some Scene { WindowGroup { RootView().environmentObject(store).environmentObject(location).tint(RoamStyle.red).preferredColorScheme(.light) } }
}
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var store: Store
    @EnvironmentObject var location: LocationService
    var body: some View {
        if store.token == nil { LoginView() } else { tabs }
    }
    private var tabs: some View {
        TabView {
            HomeView().tabItem { Label("Esplora", systemImage: "safari") }
            SearchView().tabItem { Label("Cerca", systemImage: "magnifyingglass") }
            SocialFeedView().tabItem { Label("Feed", systemImage: "rectangle.stack.fill") }
            InboxView().tabItem { Label("Chat", systemImage: "paperplane") }.badge(store.unreadChats)
            ProfileView().tabItem { Label("Profilo", systemImage: "person.crop.circle") }
        }
        .task { location.request() }
        .task {  // unread badge, like Instagram's Direct
            while !Task.isCancelled { await store.refreshUnread(); try? await Task.sleep(for: .seconds(15)) }
        }
        .task(id: location.coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "no-location") { await store.load(location.coordinate) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { location.request() } }
        .fullScreenCover(isPresented: $store.needsOnboarding) { OnboardingView() }
        .alert("Qualcosa non ha funzionato", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}
struct Avatar: View {
    let photo: String?
    var size: CGFloat = 52
    var body: some View {
        Group {
            if let photo, let data = Data(base64Encoded: photo), let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(RoamStyle.red.opacity(0.7)) }
        }.frame(width: size, height: size).clipShape(Circle())
    }
}
struct PlaceSheet: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            PlaceView(place: place)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }.foregroundStyle(RoamStyle.red)
                } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}
struct PlaceGlyph: View {
    let category: String
    var body: some View {
        if category == "Parco" || category == "Ristorante" {
            Image(systemName: category == "Parco" ? "leaf.fill" : "fork.knife").resizable().scaledToFit()
        } else {
        Image(category == "Caffè" ? "RoamCafe" : category == "Negozio" ? "RoamShop" : "RoamAttraction")
            .resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}
struct RoamMapPin: View {
    let place: Place
    var selected = false
    var body: some View {
        VStack(spacing: 2) {
            PlaceGlyph(category: place.category)
                .frame(width: 20, height: 20).padding(10)
                .foregroundStyle(selected ? .white : RoamStyle.red)
                .roamGlassCircle(tint: selected ? RoamStyle.red : nil)
            Circle().fill(selected ? RoamStyle.red : .white).frame(width: 7, height: 7)
                .overlay(Circle().stroke(selected ? .white : RoamStyle.red, lineWidth: 1.5))
        }
        .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
        .scaleEffect(selected ? 1.12 : 1)
        .accessibilityLabel("\(place.name), \(place.category)")
    }
}
struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in p.move(to: .zero); p.addLine(to: .init(x: rect.maxX, y: 0)); p.addLine(to: .init(x: rect.midX, y: rect.maxY)); p.closeSubpath() }
    }
}
struct MapGlassButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16, weight: .semibold))
            .foregroundStyle(RoamStyle.red).frame(width: 46, height: 46)
            .roamGlassCircle()
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25), value: configuration.isPressed)
    }
}
struct MapPlaceGroup: Identifiable {
    let id:String
    let places:[Place]
    var coordinate:CLLocationCoordinate2D { .init(latitude:places[0].latitude,longitude:places[0].longitude) }
}
struct ExploreMap: View {
    let places: [Place]
    let coordinate: CLLocationCoordinate2D
    var compact = false
    var categoryFilter = "Tutti"
    var searchQuery = ""
    @EnvironmentObject private var store: Store
    @State private var viewportPlaces: [Place] = []
    @State private var viewportKey = ""
    @State private var queryRegion: MKCoordinateRegion?
    @State private var viewportLoading = false
    @State private var viewportFailure: String?
    @State private var viewportCache: [String: (Date, [Place])] = [:]
    var title = "La tua zona"
    var weather = ""
    var heroHeight: CGFloat = 470
    var allowsExpand = true
    var topInset: CGFloat = 0
    var showBrand = false
    var focusedPlace: Place? = nil
    var onAreaResults: (([Place]?) -> Void)? = nil
    var onAreaLoading: ((Bool) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @State private var expanded = false
    @State private var is3D = true
    @State private var mapDistance: Double = 6500
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: MapCameraPosition = .automatic
    @State private var selection: String?
    @State private var detail: Place?
    private var displayedPlaces: [Place] {
        var merged=Dictionary(places.map { ($0.id,$0) },uniquingKeysWith: { a,_ in a })
        for place in viewportPlaces { merged[place.id]=place }
        let query=searchQuery.trimmingCharacters(in:.whitespacesAndNewlines)
        return merged.values.filter { place in
            if let r = queryRegion {
                let delta = abs(place.longitude-r.center.longitude).truncatingRemainder(dividingBy:360)
                guard abs(place.latitude-r.center.latitude) <= r.span.latitudeDelta/2, min(delta,360-delta) <= r.span.longitudeDelta/2 else { return false }
            }
            return (categoryFilter == "Tutti" || place.category == categoryFilter) && (query.isEmpty || place.name.localizedCaseInsensitiveContains(query) || place.description.localizedCaseInsensitiveContains(query)) }.sorted { $0.id < $1.id }
    }
    private var placeGroups: [MapPlaceGroup] {
        let regular=displayedPlaces
        guard mapDistance > 15000,let region=queryRegion else { return regular.map { MapPlaceGroup(id:$0.id,places:[$0]) } }
        let latStep=max(0.001,region.span.latitudeDelta/9),lonStep=max(0.001,region.span.longitudeDelta/7)
        return Dictionary(grouping:regular) { "\(Int(floor($0.latitude/latStep))):\(Int(floor($0.longitude/lonStep)))" }.map { MapPlaceGroup(id:"cluster-"+$0.key,places:$0.value.sorted{$0.id<$1.id}) }.sorted{$0.id<$1.id}
    }
    private var selectedPlace: Place? { displayedPlaces.first { $0.id == selection } }
    var body: some View {
        VStack(spacing: 0) {
            Map(position: $camera, selection: $selection) {
                Annotation("Tu sei qui", coordinate: coordinate) {
                    ZStack {
                        Color.clear.frame(width: 40, height: 40).roamGlassCircle()
                        Circle().fill(RoamStyle.red).frame(width: 14).overlay(Circle().stroke(.white, lineWidth: 3))
                    }.shadow(color: RoamStyle.red.opacity(0.25), radius: 8).accessibilityLabel("La tua posizione")
                }
                ForEach(placeGroups) { group in
                    if group.places.count == 1, let place=group.places.first {
                        Annotation(place.name,coordinate:place.coordinate,anchor:.bottom) { RoamMapPin(place:place,selected:selection == place.id) }.tag(place.id)
                    } else {
                        Annotation("\(group.places.count) luoghi",coordinate:group.coordinate) {
                            Button { moveCamera(to:group.coordinate,distance:max(700,mapDistance/3)) } label: {
                                Text("\(group.places.count)").font(.headline.monospacedDigit()).foregroundStyle(.white).frame(width:46,height:46).roamGlassCircle(tint: RoamStyle.red, interactive: true).shadow(color: .black.opacity(0.15), radius:6, y: 3)
                            }.accessibilityLabel("Mostra \(group.places.count) luoghi raggruppati")
                        }
                    }
                }
            }
            .onMapCameraChange(frequency:.continuous) { context in
                mapDistance=context.camera.distance
                let r=context.region
                queryRegion=r
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                let r = context.region
                queryRegion = r
                viewportKey = String(format: "%.5f:%.5f:%.5f:%.5f", locale: Locale(identifier: "en_US_POSIX"), r.center.latitude, r.center.longitude, r.span.latitudeDelta, r.span.longitudeDelta)
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls { MapCompass(); MapScaleView() }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 7) {
                    if showBrand {
                        HStack(spacing: 5) {
                            RoamMark().stroke(RoamStyle.red, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)).frame(width: 25, height: 25)
                            Text("roam").font(.system(.title2, design: .rounded, weight: .heavy)).tracking(-1)
                        }.padding(.bottom, 2).accessibilityLabel("Roam")
                    }
                    Label(title, systemImage: "location.fill").font(.subheadline.bold()).lineLimit(2)
                    if !weather.isEmpty { Label(weather, systemImage: "cloud.sun.fill").font(.caption).foregroundStyle(.secondary) }
                    Text("\(displayedPlaces.count) luoghi nell’area").font(.caption2.weight(.medium)).foregroundStyle(RoamStyle.red).contentTransition(.numericText())
                }.padding(14).frame(maxWidth: 220, alignment: .leading)
                    .roamGlass(23)
                    .padding(16).padding(.trailing, 60).padding(.top, topInset)
            }
            .overlay(alignment: .topTrailing) {
                RoamGlassGroup(spacing: 12) {
                VStack(spacing: 12) {
                    if !allowsExpand && onClose != nil {
                        Button { onClose?() } label: { Image(systemName: "xmark") }.accessibilityLabel("Chiudi la mappa")
                    }
                    Button { recenter() } label: { Image(systemName: "location.north.fill") }.accessibilityLabel("Centra sulla mia posizione")
                    Button { is3D.toggle() } label: { Text(is3D ? "2D" : "3D").font(.caption.bold()) }.accessibilityLabel(is3D ? "Passa alla vista 2D" : "Passa alla vista 3D")
                    if viewportLoading { ProgressView().frame(width:46,height:46).roamGlassCircle() }
                    if allowsExpand {
                        Button { expanded = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.accessibilityLabel("Apri la mappa a schermo intero")
                    }
                }.buttonStyle(MapGlassButtonStyle())
                }.padding(16).padding(.top, topInset)
            }
            .overlay(alignment: .bottom) {
                if let place = selectedPlace {
                    Button { detail = place } label: {
                        HStack(spacing: 12) {
                            PlaceVisual(place: place, height: 60).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(.black).lineLimit(2)
                                Label("\(distanceLabel(place.distance)) · \(place.category)", systemImage: "location").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.subheadline.bold()).foregroundStyle(.white).frame(width: 42, height: 42).roamGlassCircle(tint: RoamStyle.red)
                        }.padding(10).roamGlass(26, interactive: true).shadow(color: .black.opacity(0.1), radius: 14, y: 5)
                    }.buttonStyle(.plain).padding(12).padding(.bottom, allowsExpand ? 18 : 40).transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(height: compact ? 240 : heroHeight)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selection)
            .task(id: viewportKey + String(store.viewportSearchEnabled)) {
                guard !viewportKey.isEmpty,let region=queryRegion,store.viewportSearchEnabled else { viewportLoading=false;viewportPlaces=[];onAreaResults?(nil);onAreaLoading?(false);return }
                let key=viewportKey
                onAreaLoading?(true)
                do {
                    try await Task.sleep(for:.milliseconds(550))
                    if let cached=viewportCache[key],Date().timeIntervalSince(cached.0)<600 { viewportPlaces=cached.1;viewportLoading=false;viewportFailure=nil;publishArea(region);onAreaLoading?(false);return }
                    viewportLoading=true;viewportFailure=nil
                    defer { if !Task.isCancelled { viewportLoading=false;onAreaLoading?(false) } }
                    let loaded=try await store.searchViewport(region,origin:coordinate) { partial in
                        viewportPlaces=partial
                        publishArea(region)
                    }
                    try Task.checkCancellation()
                    if viewportCache.count>=20 { viewportCache.removeAll() }
                    viewportCache[key]=(Date(),loaded);viewportPlaces=loaded;publishArea(region)
                } catch { if !Task.isCancelled { viewportLoading=false;viewportFailure="Ricerca nell’area non disponibile";onAreaLoading?(false) } }
            }
            .overlay(alignment:.bottomTrailing) {
                if let viewportFailure { Text(viewportFailure).font(.caption2).padding(8).roamGlassCapsule().padding(.bottom,28).padding(.trailing,12) }
            }
            .onChange(of: displayedPlaces.map(\.id)) { _, ids in if let selection, !ids.contains(selection) { self.selection = nil } }
            .task(id: "\(coordinate.latitude),\(coordinate.longitude)") { recenter() }
        }
        .clipShape(RoundedRectangle(cornerRadius: allowsExpand ? 28 : 0, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
        .sheet(item: $detail) { PlaceSheet(place: $0) }
        .onChange(of: focusedPlace?.id) { _, _ in
            guard let place = focusedPlace else { return }
            selection = place.id
            moveCamera(to: place.coordinate, distance: 1800)
        }
        .onChange(of: is3D) { _, _ in moveCamera(to: camera.camera?.centerCoordinate ?? coordinate, distance: mapDistance) }
        .onChange(of: selection) { _, _ in
            guard let place = selectedPlace else { return }
            moveCamera(to: place.coordinate, distance: 2000)
        }
        .fullScreenCover(isPresented: $expanded) {
            GeometryReader { proxy in
                ExploreMap(places: places, coordinate: coordinate,categoryFilter:categoryFilter,searchQuery:searchQuery,title: title, weather: weather, heroHeight: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom, allowsExpand: false, topInset: proxy.safeAreaInsets.top, showBrand: true, onAreaResults: onAreaResults, onAreaLoading: onAreaLoading, onClose: { expanded = false })
                    .ignoresSafeArea()
            }
        }
    }
    private func publishArea(_ region: MKCoordinateRegion) {
        var merged = Dictionary(places.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for place in viewportPlaces { merged[place.id] = place }
        onAreaResults?(merged.values.filter { place in
            let delta = abs(place.longitude-region.center.longitude).truncatingRemainder(dividingBy: 360)
            return abs(place.latitude-region.center.latitude) <= region.span.latitudeDelta/2 && min(delta,360-delta) <= region.span.longitudeDelta/2
        }.sorted { $0.distance < $1.distance })
    }
    private func recenter() { moveCamera(to: coordinate, distance: compact ? 1800 : 6500) }
    private func moveCamera(to center: CLLocationCoordinate2D, distance: Double) {
        let target = MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: is3D ? 45 : 0)
        if reduceMotion { camera = .camera(target) }
        else { withAnimation(.easeInOut(duration: 0.75)) { camera = .camera(target) } }
    }

}
struct TravelDashboard: View {
    let profile: Profile
    let stats: Stats
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Avatar(photo: profile.photo)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bentornato, esploratore").font(.subheadline).foregroundStyle(.secondary)
                    Text(profile.name).font(.title2.bold()).foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Image(systemName: "sparkle").font(.title3).foregroundStyle(RoamStyle.red)
            }
            Divider()
            HStack(spacing: 0) {
                metric(stats.posts, "Post", "photo.on.rectangle")
                Spacer(minLength: 6)
                metric(stats.places, "Luoghi", "mappin.and.ellipse")
                Spacer(minLength: 6)
                metric(stats.comments, "Commenti", "bubble.left")
            }
        }.padding(20).roamGlass(26)
    }
    private func metric(_ value: Int, _ title: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(RoamStyle.red)
            Text("\(value)").font(.title2.bold()).contentTransition(.numericText())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var location: LocationService
    @State private var filter = "Tutti"
    @State private var searchText = ""
    @State private var showPlaceFilters = false
    @State private var areaPlaces: [Place]?
    @State private var areaLoading = false
    private var feedPlaces: [Place] { areaPlaces ?? store.places }
    private var visiblePlaces: [Place] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return feedPlaces.filter { place in
            (filter == "Tutti" || place.category == filter) &&
            (query.isEmpty || place.name.localizedCaseInsensitiveContains(query) || place.category.localizedCaseInsensitiveContains(query) || place.description.localizedCaseInsensitiveContains(query))
        }.sorted { $0.distance < $1.distance }
    }
    @State private var focusedPlace: Place?
    @State private var openedPlace: Place?
    @Namespace private var categorySelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if let coordinate = location.coordinate {
                        ExploreMap(places: store.places, coordinate: coordinate,categoryFilter:filter,searchQuery:searchText,title: location.city, weather: location.weather, heroHeight: 400 + geometry.safeAreaInsets.top, topInset: geometry.safeAreaInsets.top, showBrand: true, focusedPlace: focusedPlace, onAreaResults: { areaPlaces = $0; store.mapAreaPlaces = $0 }, onAreaLoading: { areaLoading = $0 })
                            .id("home-map").padding(.horizontal, -24).padding(.top, -18)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("La tua prossima scoperta", systemImage: "map").font(.title2.bold())
                            Text("Attiva la posizione per esplorare la mappa e i luoghi vicini.").font(.subheadline).foregroundStyle(.secondary)
                            Button("Usa la mia posizione") { location.request() }.buttonStyle(.borderedProminent).tint(RoamStyle.red)
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).roamGlass(28).padding(.top, geometry.safeAreaInsets.top)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(areaPlaces == nil ? "VICINO A TE" : "NELLA ZONA SULLA MAPPA").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(RoamStyle.red)
                            Text("Guardati\nintorno.").font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1.4).lineSpacing(-3)
                        }
                        Spacer()
                        if store.loading || areaLoading { ProgressView() }
                        Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showPlaceFilters.toggle() } } label: {
                            Image(systemName: showPlaceFilters ? "xmark" : "line.3.horizontal.decrease")
                        }.buttonStyle(MapGlassButtonStyle()).accessibilityLabel(showPlaceFilters ? "Nascondi ricerca e filtri" : "Mostra ricerca e filtri")
                    }
                    if showPlaceFilters {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").foregroundStyle(RoamStyle.red)
                        TextField("Cerca luoghi e attrazioni", text: $searchText).font(.subheadline).submitLabel(.search).autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("Cancella ricerca")
                        }
                    }.padding(.horizontal, 18).padding(.vertical, 15).roamGlassCapsule()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Tutti", "Attrazione", "Parco", "Ristorante", "Caffè", "Negozio"], id: \.self) { category in
                                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) { filter = category } } label: {
                                    HStack(spacing: 7) {
                                        if category != "Tutti" { PlaceGlyph(category: category).frame(width: 18, height: 18) }
                                        Text(category == "Attrazione" ? "Da vedere" : category == "Negozio" ? "Shopping" : category).font(.subheadline.weight(.semibold))
                                    }.padding(.horizontal, 16).padding(.vertical, 12).foregroundStyle(filter == category ? .white : .primary)
                                    .roamGlassCapsule(interactive: true, tint: filter == category ? RoamStyle.red : nil)
                                }.buttonStyle(.plain).accessibilityAddTraits(filter == category ? .isSelected : [])
                            }
                        }
                    }
                    if !visiblePlaces.isEmpty {
                        HStack {
                            Text("\(visiblePlaces.count) luoghi da scoprire").font(.subheadline.weight(.semibold))
                            Spacer()
                            Label("Più vicini", systemImage: "location.fill").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .padding(.horizontal, 10).padding(.vertical, 6).roamGlassCapsule()
                        }
                    }
                    LazyVStack(spacing: 18) {
                        ForEach(visiblePlaces) { place in
                            PlaceFeedCard(place: place, onOpen: { openedPlace = place }, onMap: {
                                focusedPlace = nil
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { scrollProxy.scrollTo("home-map", anchor: .top) }
                                Task { @MainActor in await Task.yield(); focusedPlace = place }
                            })
                        }
                    }
                    if let issue = store.placesError {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(issue, systemImage: "wifi.exclamationmark").font(.subheadline)
                            Button("Riprova") { Task { await store.loadPlaces(location.coordinate) } }.disabled(store.loading).tint(RoamStyle.red)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).roamGlass(22)
                    }
                    if !store.appleSearchEnabled, location.coordinate != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Cerca anche con Mappe Apple").font(.headline)
                            Text("Attivando questa ricerca, invii la tua posizione ad Apple per trovare luoghi vicini. Puoi disattivarla nel profilo.").font(.caption).foregroundStyle(.secondary)
                            Button("Attiva ricerca con Mappe Apple") {
                                store.appleSearchEnabled = true
                                Task { await store.loadPlaces(location.coordinate) }
                            }.buttonStyle(.borderedProminent).tint(RoamStyle.red)
                        }.padding().roamGlass(22)
                    }
                    if feedPlaces.isEmpty && !areaLoading {
                        ContentUnavailableView {
                            Label(location.coordinate == nil ? "Esplora la tua zona" : store.loading ? "Cerco luoghi vicini…" : "Nessun luogo caricato", systemImage: "location.magnifyingglass")
                        } description: {
                            Text(location.coordinate == nil ? "Consenti la posizione per trovare attrazioni, caffè e negozi e leggere il meteo locale." : areaPlaces == nil ? "Ricerca entro 5 km. Trascina per riprovare." : "Nessun luogo trovato in quest’area. Sposta o allarga la mappa.")
                        } actions: {
                            if location.permissionDenied { Button("Apri Impostazioni") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
                            else if location.coordinate == nil { Button("Usa la mia posizione") { location.request() } }
                            else { Button("Riprova ricerca") { Task { await store.loadPlaces(location.coordinate) } }.disabled(store.loading) }
                        }
                    }
                    if !feedPlaces.isEmpty && visiblePlaces.isEmpty {
                        ContentUnavailableView.search(text: searchText.isEmpty ? filter : searchText)
                    }
                    HStack(alignment: .top) {
                        Text(areaPlaces == nil ? "Luoghi entro 5 km · " + store.source : "Luoghi nell’area della mappa · Mappe Apple").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Link(store.source == "Mappe Apple" ? "Mappe Apple" : "© OpenStreetMap", destination: URL(string: store.source == "Mappe Apple" ? "https://maps.apple.com/" : "https://www.openstreetmap.org/copyright")!).font(.caption2)
                        Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!).font(.caption2)
                    }.padding(.top, 2)
                }.padding(.horizontal, 24).padding(.vertical, 18)
            }.scrollDismissesKeyboard(.interactively)
                .background {
                    ZStack {
                        RoamStyle.canvas
                        LinearGradient(colors: [.clear, RoamStyle.red.opacity(0.06), Color(red: 1, green: 0.95, blue: 0.92).opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                    }.ignoresSafeArea()
                }
                .toolbar(.hidden, for: .navigationBar)
                .ignoresSafeArea(edges: .top)
                .sensoryFeedback(.selection, trigger: filter)
                .sheet(item: $openedPlace) { PlaceSheet(place: $0) }
                .refreshable { await store.load(location.coordinate); await location.refreshWeather() }
            }
            }
        }
    }
}
@MainActor final class PlaceImageCache {
    static let shared = PlaceImageCache()
    let images = NSCache<NSString, UIImage>()
    init() { images.countLimit = 60 }
}
struct PlaceVisual: View {
    let place:Place
    var height:CGFloat=188
    var prominent=false
    @EnvironmentObject var store:Store
    @State private var failed=false
    private var uploaded:UIImage? {
        guard let photo=store.activity[place.id]?.photo,let data=Data(base64Encoded:photo) else { return nil }
        return UIImage(data:data)
    }
    var body:some View {
        ZStack(alignment:.bottomLeading) {
            if let image=uploaded {
                GeometryReader { p in Image(uiImage:image).resizable().scaledToFill().frame(width:p.size.width,height:p.size.height).clipped() }
            } else if let photo=store.webPhotos[place.id],let url=URL(string:photo.url),!failed {
                AsyncImage(url:url) { phase in
                    if let image=phase.image { GeometryReader { p in image.resizable().scaledToFill().frame(width:p.size.width,height:p.size.height).clipped() } }
                    else if phase.error != nil { placeholder.onAppear { if !store.nextWebPhoto(place) { failed=true } } }
                    else { placeholder.overlay { ProgressView() } }
                }.id(photo.url)
            } else if let image=communityImage {
                GeometryReader { p in Image(uiImage:image).resizable().scaledToFill().frame(width:p.size.width,height:p.size.height).clipped() }
            } else { placeholder }
            LinearGradient(colors:[.clear,.black.opacity(0.4)],startPoint:.center,endPoint:.bottom).allowsHitTesting(false)
            if let caption { Text(caption)
                .font(.caption2.weight(.medium)).foregroundStyle(.white).padding(.horizontal,9).padding(.vertical,6).background(.black.opacity(0.35),in:Capsule()).padding(12)
                .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:prominent ? .topTrailing : .bottomLeading).padding(.top,prominent ? 44 : 0) }
        }.frame(height:height).clipped().task(id:place.id) {
            await store.loadWebPhoto(place)
            if store.webPhotos[place.id] == nil { await store.loadPlacePosts(place) }
        }
        .onChange(of: failed) { _, value in if value { Task { await store.loadPlacePosts(place) } } }
    }
    private var webShown: Bool { store.webPhotos[place.id] != nil && !failed }
    private var communityImage: UIImage? { store.communityPhotos(place.id).lazy.compactMap { PostImageCache.image($0) }.first }
    private var caption: String? {
        if uploaded != nil || (!webShown && communityImage != nil) { return "Foto della community" }
        if webShown { return store.webPhotos[place.id]?.provider == "google_images" ? "Google Immagini · fonte verificata" : "Wikimedia Commons" }
        return nil
    }
    private var placeholder:some View { ZStack { RoamStyle.surface;PlaceGlyph(category:place.category).frame(width:48,height:48).foregroundStyle(RoamStyle.red.opacity(0.5)) } }
}
struct DiscoveryPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
// Decoding multi-megabyte base64 photos on every render makes scrolling stutter.
// Feed and profile use only white, red and black.
struct RoamTabs: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = option } } label: {
                    Text(option).font(.subheadline.weight(selection == option ? .bold : .medium)).lineLimit(1).minimumScaleFactor(0.75)
                        .foregroundStyle(selection == option ? .white : .black)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background { if selection == option { Capsule().fill(RoamStyle.red) } }
                        .contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(4).roamGlassCapsule()
        .sensoryFeedback(.selection, trigger: selection)
    }
}
struct RoamEmptyState: View {
    let icon, title, message: String
    var action: String? = nil
    var perform: () -> Void = {}
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(RoamStyle.red)
            Text(title).font(.title3.bold()).foregroundStyle(.black).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(.black).multilineTextAlignment(.center)
            if let action {
                Button(action: perform) {
                    Text(action).font(.subheadline.bold()).foregroundStyle(.white).padding(.horizontal, 20).frame(height: 40).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                }.buttonStyle(DiscoveryPressStyle()).padding(.top, 4)
            }
        }.frame(maxWidth: .infinity).padding(.horizontal, 32)
    }
}
@MainActor enum PostImageCache {
    private static let cache = NSCache<NSString, UIImage>()
    static func image(_ post: SocialPost) -> UIImage? {
        guard let photo = post.photo else { return nil }
        if let hit = cache.object(forKey: post.id as NSString) { return hit }
        guard let data = Data(base64Encoded: photo), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: post.id as NSString)
        return image
    }
}
struct SocialFeedView: View {
    @EnvironmentObject private var store: Store
    @AppStorage("feedScope") private var scope = "Vicino a te"
    @State private var composing = false
    @State private var commenting: SocialPost?
    @State private var openedPlace: Place?
    @State private var openedPostID: String?
    private var following: Bool { scope == "Seguiti" }
    private var areaPlaces: [Place] { scope == "Sulla mappa" ? store.mapAreaPlaces ?? store.places : store.places }
    private var queryKey: String { scope + "|" + (scope == "Salvati" ? "saved" : following ? "following-\(store.stats.following)" : areaPlaces.map(\.id).sorted().joined(separator: "|")) }
    private var posts: [SocialPost] { store.socialPosts.filter { scope == "Salvati" ? $0.saved : following ? ($0.following == true || $0.mine) : true } }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    RoamTabs(options: ["Seguiti", "Vicino a te", "Sulla mappa", "Salvati"], selection: $scope).padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
                    if scope == "Sulla mappa" {
                        Label("I post dei luoghi nell’ultima zona esplorata in Esplora.", systemImage: "map").font(.caption).foregroundStyle(.black).padding(.horizontal, 16).padding(.bottom, 12)
                    }
                    if scope != "Salvati" {
                        Button { composing = true } label: {
                            HStack(spacing: 12) {
                                Avatar(photo: store.profile.photo, size: 38)
                                Text("Che posto hai scoperto?").font(.subheadline).foregroundStyle(.black)
                                Spacer(minLength: 0)
                                Image(systemName: "photo.badge.plus").font(.title3).foregroundStyle(RoamStyle.red)
                            }.padding(.horizontal, 12).padding(.vertical, 10).roamGlassCapsule(interactive: true).contentShape(Capsule())
                        }.buttonStyle(DiscoveryPressStyle()).padding(.horizontal, 16).padding(.bottom, 16)
                    }
                    if let issue = store.socialError {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(issue).font(.subheadline)
                            Button("Riprova") { Task { await reload() } }
                        }.padding(16)
                    }
                    if posts.isEmpty && !store.socialLoading && store.socialError == nil && following {
                        RoamEmptyState(icon: "person.2", title: "Segui altri viaggiatori", message: "Tocca Segui accanto al nome di chi pubblica, oppure trova persone in Cerca → Persone. I loro post appariranno qui.").padding(.top, 40)
                    } else if posts.isEmpty && !store.socialLoading && store.socialError == nil {
                        RoamEmptyState(icon: scope == "Salvati" ? "bookmark" : "photo.on.rectangle.angled", title: scope == "Salvati" ? "Le storie da conservare" : "La prima storia può essere la tua", message: scope == "Salvati" ? "Salva un post con il segnalibro e lo ritroverai qui." : areaPlaces.isEmpty ? "Esplora la mappa per caricare i luoghi, poi condividi la tua esperienza." : "Qui troverai foto e racconti dei luoghi di questa zona. Condividi la tua prima scoperta.", action: scope == "Salvati" ? nil : "Pubblica un’esperienza") { composing = true }.padding(.top, 40)
                    }
                    ForEach(posts) { post in
                        SocialPostPreview(post: post, place: areaPlaces.first { $0.id == post.place_id } ?? post.place) { openedPostID = post.id }
                            .padding(.horizontal, 16).padding(.bottom, 16)
                    }
                    if store.socialLoading { ProgressView("Carico le esperienze…").frame(maxWidth: .infinity).padding() }
                    if store.socialHasMore && !store.socialLoading {
                        Color.clear.frame(height: 1).onAppear { Task { await store.loadSocialFeed(ids: areaPlaces.map(\.id), savedOnly: scope == "Salvati", following: following, append: true) } }
                    }
                }
            }.background { GlassBackdrop() }.navigationTitle("Feed").roamHeader()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { Button { composing = true } label: { Image(systemName: "plus.app") }.accessibilityLabel("Pubblica un’esperienza") }
                }
                .task(id: queryKey) {
                    do { try await Task.sleep(for: .milliseconds(350)); try Task.checkCancellation() } catch { return }
                    await reload()
                }
                .refreshable { await reload() }
                .sheet(isPresented: $composing) { SocialComposer(places: store.knownPlaces) { _ in Task { await reload() } } }
                .sheet(item: $commenting) { SocialCommentsView(post: $0) }
                .sheet(item: $openedPlace) { PlaceSheet(place: $0) }
                .navigationDestination(item: $openedPostID) { id in
                    if let post = store.socialPosts.first(where: { $0.id == id }) {
                        SocialPostDetailView(initial: post, place: areaPlaces.first { $0.id == post.place_id } ?? post.place)
                    }
                }
        }
    }
    private func reload() async { await store.loadSocialFeed(ids: areaPlaces.map(\.id), savedOnly: scope == "Salvati", following: following) }
}

struct SocialPostCard: View {
    let post: SocialPost
    let place: Place
    let onPlace: () -> Void
    let onComment: () -> Void
    var onDeleted: (() -> Void)? = nil
    @EnvironmentObject private var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var saving = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var expanded = false
    @State private var showingAuthor = false
    @State private var sending = false
    @State private var followBusy = false
    @State private var burst = false
    private var authorPerson: Person? {
        guard !post.mine, let key = post.author_key else { return nil }
        return Person(key: key, name: post.author, photo: post.author_profile?.photo)
    }
    private var image: UIImage? { PostImageCache.image(post) }
    private var dateLabel: String {
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: post.created_at) ?? ISO8601DateFormatter().date(from: post.created_at) else { return "" }
        if Date().timeIntervalSince(date) > 7 * 86400 { return date.formatted(.dateTime.day().month(.wide).year()) }
        let relative = RelativeDateTimeFormatter(); relative.locale = Locale(identifier: "it_IT")
        return relative.localizedString(for: date, relativeTo: Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if post.mine { Avatar(photo: store.profile.photo, size: 34) }
                else {
                    Button { showingAuthor = true } label: { Avatar(photo: post.author_profile?.photo, size: 34) }
                        .buttonStyle(.plain).disabled(authorPerson == nil)
                        .accessibilityLabel("Profilo di \(post.author)")
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Button { showingAuthor = true } label: { Text(post.mine ? store.profile.name : post.author).font(.subheadline.bold()).lineLimit(1) }
                            .buttonStyle(.plain).disabled(authorPerson == nil)
                        if let person = authorPerson, post.following == false {
                            Text("•").font(.caption).foregroundStyle(.secondary)
                            Button {
                                followBusy = true
                                Task { _ = try? await store.setFollowing(person.key, true); followBusy = false }
                            } label: { Text("Segui").font(.subheadline.bold()).foregroundStyle(RoamStyle.red) }
                                .buttonStyle(.plain).disabled(followBusy).accessibilityLabel("Segui \(post.author)")
                        }
                    }
                    Button(action: onPlace) {
                        HStack(spacing: 3) { Image(systemName: "mappin"); Text(place.name).lineLimit(1) }.font(.caption)
                    }.buttonStyle(.plain).accessibilityLabel("Luogo: \(place.name). Apri")
                }
                Spacer(minLength: 4)
                Menu {
                    Button { onPlace() } label: { Label("Vedi il luogo", systemImage: "mappin.circle") }
                    Button { directions() } label: { Label("Portami qui", systemImage: "arrow.triangle.turn.up.right.diamond") }
                    if post.mine {
                        Divider()
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Elimina post", systemImage: "trash") }
                    }
                } label: { Image(systemName: "ellipsis").font(.body.weight(.semibold)).foregroundStyle(.primary).frame(width: 36, height: 36).contentShape(Rectangle()) }
                    .accessibilityLabel("Altre azioni")
            }.padding(.horizontal, 12).padding(.vertical, 8)
            ZStack {
                if let image {
                    Color.clear.aspectRatio(4 / 5, contentMode: .fit)
                        .overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
                } else { PlaceVisual(place: place, height: 320) }
                Image(systemName: "bookmark.fill").font(.system(size: 72)).foregroundStyle(.white).shadow(radius: 10)
                    .scaleEffect(burst ? 1 : 0.4).opacity(burst ? 1 : 0).allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { saveFromDoubleTap() }
            .accessibilityAction(named: "Salva") { saveFromDoubleTap() }
            .accessibilityLabel("Foto di \(place.name)")
            HStack(spacing: 16) {
                Button(action: onComment) { Image(systemName: "bubble.right") }.accessibilityLabel("Commenta")
                share
                Button { sending = true } label: { Image(systemName: "paperplane") }.accessibilityLabel("Invia in chat")
                Spacer()
                Button {
                    saving = true
                    Task { await store.toggleSaved(post); saving = false }
                } label: { Image(systemName: post.saved ? "bookmark.fill" : "bookmark") }.disabled(saving).accessibilityLabel(post.saved ? "Rimuovi dai salvati" : "Salva esperienza")
            }.font(.title3).foregroundStyle(.primary).buttonStyle(.plain).padding(.horizontal, 14).padding(.top, 10)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) { ForEach(0..<5) { i in Image(systemName: i < post.rating ? "star.fill" : "star").font(.caption2) } }
                    .foregroundStyle(RoamStyle.red).accessibilityElement(children: .ignore).accessibilityLabel("Valutazione \(post.rating) su 5")
                Text("\(Text(post.mine ? store.profile.name : post.author).bold()) \(post.body)").font(.subheadline)
                    .lineLimit(expanded ? nil : 2).fixedSize(horizontal: false, vertical: true)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() } }
                Button(action: onComment) {
                    Text(post.comments == 0 ? "Aggiungi un commento…" : post.comments == 1 ? "Visualizza 1 commento" : "Visualizza tutti i \(post.comments) commenti")
                        .font(.subheadline).foregroundStyle(.black)
                }.buttonStyle(.plain)
                if post.is_demo == true { Text("Demo · contenuti e immagini generati").font(.caption2).foregroundStyle(.secondary) }
                Text(dateLabel).font(.caption2).foregroundStyle(.black)
            }.padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 18)
        }
        .sheet(isPresented: $showingAuthor) {
            if let person = authorPerson { PersonSheet(person: person) }
        }
        .sheet(isPresented: $sending) { SendPostSheet(post: post) }
        .opacity(deleting ? 0.4 : 1).disabled(deleting)
        .confirmationDialog("Eliminare il post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                deleting = true
                Task { if await store.deletePost(post) { onDeleted?() }; deleting = false }
            }
            Button("Annulla", role: .cancel) {}
        } message: { Text("Il post e i suoi commenti verranno rimossi da Feed e Profilo.") }
    }
    @ViewBuilder private var share: some View {
        if let image {
            let preview = Image(uiImage: image)
            ShareLink(item: preview, subject: Text(place.name), message: Text("\(place.name) — \(post.body)"), preview: SharePreview(place.name, image: preview)) { Image(systemName: "square.and.arrow.up") }
        } else {
            ShareLink(item: "\(place.name) — \(post.body)") { Image(systemName: "square.and.arrow.up") }
        }
    }
    private func directions() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)); item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
    // Like Instagram's double-tap: only ever adds, never removes.
    private func saveFromDoubleTap() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55)) { burst = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { withAnimation(.easeOut(duration: 0.25)) { burst = false } }
        guard !post.saved, !saving else { return }
        saving = true
        Task { await store.toggleSaved(post); saving = false }
    }
}

// Same frosted surface as the map overlays: material plus a thin white rim.
// iOS 26+ gets real Liquid Glass; earlier systems keep the frosted material.
extension View {
    @ViewBuilder func roamGlass(_ radius: CGFloat = 22, interactive: Bool = false, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, *) { glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape) }
        else if let tint { background(tint, in: shape) }
        else { background(.regularMaterial, in: shape).overlay(shape.stroke(.white.opacity(0.6), lineWidth: 1)) }
    }
    @ViewBuilder func roamGlassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(Glass.regular.tint(tint).interactive(interactive), in: Capsule())
        } else if let tint { background(tint, in: Capsule()) }
        else { background(.regularMaterial, in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1)) }
    }
    /// System lists and forms on the shared backdrop, rows on frosted glass.
    func roamGlassForm() -> some View {
        scrollContentBackground(.hidden).background { GlassBackdrop() }
    }
    /// A list row drawn as its own glass card, without separators.
    func roamGlassRow() -> some View {
        padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
            .roamGlass(20, interactive: true)
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }
    @ViewBuilder func roamGlassCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) { glassEffect(Glass.regular.tint(tint).interactive(interactive), in: Circle()) }
        else if let tint { background(tint, in: Circle()).overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2)) }
        else { background(.regularMaterial, in: Circle()).overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1)) }
    }
}
// Warm, softly tinted canvas behind every screen so Liquid Glass has something to refract.
struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            RoamStyle.canvas
            LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.93), .clear, RoamStyle.red.opacity(0.05)], startPoint: .top, endPoint: .bottom)
            Circle().fill(RoamStyle.red.opacity(0.07)).frame(width: 320).blur(radius: 80).offset(x: 140, y: -260)
            Circle().fill(Color.orange.opacity(0.06)).frame(width: 280).blur(radius: 80).offset(x: -150, y: 260)
        }.ignoresSafeArea()
    }
}
/// Groups glass shapes so iOS 26 can blend them; a plain container before.
struct RoamGlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content
    var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: spacing) { content } } else { content }
    }
}
struct GlassRowBackground: View {
    var body: some View { Rectangle().fill(.ultraThinMaterial).overlay(Color.white.opacity(0.35)) }
}
func postDateLabel(_ value: String) -> String {
    let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = parser.date(from: value) ?? ISO8601DateFormatter().date(from: value) else { return "" }
    if Date().timeIntervalSince(date) > 7 * 86400 { return date.formatted(.dateTime.day().month(.wide).year()) }
    let relative = RelativeDateTimeFormatter(); relative.locale = Locale(identifier: "it_IT")
    return relative.localizedString(for: date, relativeTo: Date())
}
func distanceLabel(_ km: Double) -> String { km < 1 ? "\(Int(km * 1000)) m" : String(format: "%.1f km", km) }
struct RatingStars: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 2) { ForEach(0..<5) { i in Image(systemName: i < rating ? "star.fill" : "star").font(.caption2) } }
            .foregroundStyle(RoamStyle.red).accessibilityElement(children: .ignore).accessibilityLabel("Valutazione \(rating) su 5")
    }
}

// Feed preview: one photo, the place and a single line of text. Tap for everything else.
struct SocialPostPreview: View {
    let post: SocialPost
    let place: Place
    // Compact: the smaller bubble shown inside a chat.
    var compact = false
    let onOpen: () -> Void
    @EnvironmentObject private var store: Store
    @State private var saving = false
    private var image: UIImage? { PostImageCache.image(post) }
    private var photoHeight: CGFloat { compact ? 250 : 300 }
    private var otherPhotos: Int { store.socialPosts.filter { $0.place_id == post.place_id && $0.id != post.id && $0.photo != nil }.count }
    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottom) {
                Group {
                    if let image { Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped() }
                    else { PlaceVisual(place: place, height: photoHeight) }
                }.frame(height: photoHeight).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(place.name).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(.black).lineLimit(1)
                        Spacer(minLength: 4)
                        RatingStars(rating: post.rating)
                    }
                    Text(post.body).font(compact ? .caption : .subheadline).foregroundStyle(.black.opacity(0.75)).lineLimit(1)
                    HStack(spacing: 12) {
                        Label(distanceLabel(place.distance), systemImage: "location")
                        if !compact {
                            Label("\(post.comments)", systemImage: "bubble.right")
                            if otherPhotos > 0 { Label("+\(otherPhotos)", systemImage: "photo.stack") }
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 3) { Text("Dettagli"); Image(systemName: "chevron.right") }.foregroundStyle(RoamStyle.red).fontWeight(.semibold)
                    }.font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                }.padding(compact ? 11 : 14).roamGlass(compact ? 18 : 22).padding(compact ? 8 : 10)
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 7) {
                    Avatar(photo: post.mine ? store.profile.photo : post.author_profile?.photo, size: 24)
                    Text(post.mine ? store.profile.name : post.author).font(.caption.bold()).foregroundStyle(.black).lineLimit(1)
                    if !compact { Text(postDateLabel(post.created_at)).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }.padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4).roamGlassCapsule().padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        }
        .buttonStyle(DiscoveryPressStyle())
        .overlay(alignment: .topTrailing) {
            if !compact { Button {
                saving = true
                Task { await store.toggleSaved(post); saving = false }
            } label: { Image(systemName: post.saved ? "bookmark.fill" : "bookmark") }
                .buttonStyle(MapGlassButtonStyle()).disabled(saving).padding(10)
                .accessibilityLabel(post.saved ? "Rimuovi dai salvati" : "Salva esperienza") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(place.name), di \(post.mine ? store.profile.name : post.author). Apri i dettagli")
    }
}

// Full post: photo gallery of the place, the complete story, actions and place info.
struct SocialPostDetailView: View {
    let initial: SocialPost
    let place: Place
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var saving = false
    @State private var commenting = false
    @State private var sending = false
    @State private var showingAuthor = false
    @State private var showingPlace = false
    @State private var followBusy = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var burst = false
    @State private var localSaved: Bool?
    @State private var latestComments: [SocialComment] = []
    private var tracked: SocialPost? { store.socialPosts.first { $0.id == initial.id } ?? store.myPosts.first { $0.id == initial.id } ?? store.personFeed.first { $0.id == initial.id } }
    private var post: SocialPost {
        if let tracked { return tracked }
        var copy = initial; if let localSaved { copy.saved = localSaved }; return copy
    }
    private func toggleSave() {
        let target = !post.saved
        saving = true
        Task { await store.toggleSaved(post); if tracked == nil { localSaved = target }; saving = false }
    }
    private var image: UIImage? { PostImageCache.image(post) }
    private var authorName: String { post.mine ? store.profile.name : post.author }
    private var authorPerson: Person? {
        guard !post.mine, let key = post.author_key else { return nil }
        return Person(key: key, name: post.author, photo: post.author_profile?.photo)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                gallery
                author
                story
                actions
                conversation
                placeCard
            }.padding(.horizontal, 16).padding(.bottom, 32)
        }
        .background {
            ZStack {
                RoamStyle.canvas
                if let image { Image(uiImage: image).resizable().scaledToFill().blur(radius: 70).opacity(0.55) }
                Color.white.opacity(0.35)
            }.ignoresSafeArea()
        }
        .navigationTitle(place.name).roamHeader()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingPlace = true } label: { Label("Vedi il luogo", systemImage: "mappin.circle") }
                    Button { directions() } label: { Label("Portami qui", systemImage: "arrow.triangle.turn.up.right.diamond") }
                    if post.mine {
                        Divider()
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Elimina post", systemImage: "trash") }
                    }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Altre azioni")
            }
        }
        .sheet(isPresented: $commenting, onDismiss: { Task { await loadComments() } }) { SocialCommentsView(post: post) }
        .sheet(isPresented: $sending) { SendPostSheet(post: post) }
        .task(id: initial.id) { await loadComments() }
        .sheet(isPresented: $showingPlace) { PlaceSheet(place: place) }
        .sheet(isPresented: $showingAuthor) { if let person = authorPerson { PersonSheet(person: person) } }
        .opacity(deleting ? 0.4 : 1).disabled(deleting)
        .confirmationDialog("Eliminare il post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                deleting = true
                Task { if await store.deletePost(post) { dismiss() }; deleting = false }
            }
            Button("Annulla", role: .cancel) {}
        } message: { Text("Il post e i suoi commenti verranno rimossi da Feed e Profilo.") }
    }

    private var gallery: some View {
        PlacePhotoGallery(place: place, leading: [post])
            .overlay {
                Image(systemName: "bookmark.fill").font(.system(size: 72)).foregroundStyle(.white).shadow(radius: 10)
                    .scaleEffect(burst ? 1 : 0.4).opacity(burst ? 1 : 0).allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
            .onTapGesture(count: 2) { saveFromDoubleTap() }
            .accessibilityAction(named: "Salva") { saveFromDoubleTap() }
            .padding(.top, 8)
    }

    private var author: some View {
        HStack(spacing: 12) {
            Button { showingAuthor = true } label: { Avatar(photo: post.mine ? store.profile.photo : post.author_profile?.photo, size: 44) }
                .buttonStyle(.plain).disabled(authorPerson == nil).accessibilityLabel("Profilo di \(authorName)")
            VStack(alignment: .leading, spacing: 2) {
                Button { showingAuthor = true } label: { Text(authorName).font(.headline).foregroundStyle(.black).lineLimit(1) }
                    .buttonStyle(.plain).disabled(authorPerson == nil)
                Text(postDateLabel(post.created_at)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let person = authorPerson, post.following == false {
                Button {
                    followBusy = true
                    Task { _ = try? await store.setFollowing(person.key, true); followBusy = false }
                } label: { Text("Segui").font(.subheadline.bold()).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 34).background(RoamStyle.red, in: Capsule()) }
                    .buttonStyle(DiscoveryPressStyle()).disabled(followBusy).accessibilityLabel("Segui \(authorName)")
            }
        }.padding(14).roamGlass(24)
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 10) {
            RatingStars(rating: post.rating)
            Text(post.body).font(.body).foregroundStyle(.black).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            if post.is_demo == true { Text("Demo · contenuti e immagini generati").font(.caption2).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).roamGlass(24)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            action(post.comments == 0 ? "Commenta" : "\(post.comments)", "bubble.right") { commenting = true }
                .accessibilityLabel(post.comments == 0 ? "Commenta" : "\(post.comments) commenti")
            action("Invia", "paperplane") { sending = true }
            share
            action(post.saved ? "Salvato" : "Salva", post.saved ? "bookmark.fill" : "bookmark") { toggleSave() }.disabled(saving)
        }
    }
    private func action(_ title: String, _ icon: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) { actionLabel(title, icon) }.buttonStyle(DiscoveryPressStyle())
    }
    private func actionLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(RoamStyle.red)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.black).lineLimit(1)
        }.frame(maxWidth: .infinity).frame(height: 62).roamGlass(20)
    }
    @ViewBuilder private var share: some View {
        if let image {
            let preview = Image(uiImage: image)
            ShareLink(item: preview, subject: Text(place.name), message: Text("\(place.name) — \(post.body)"), preview: SharePreview(place.name, image: preview)) { actionLabel("Condividi", "square.and.arrow.up") }
                .buttonStyle(DiscoveryPressStyle())
        } else {
            ShareLink(item: "\(place.name) — \(post.body)") { actionLabel("Condividi", "square.and.arrow.up") }.buttonStyle(DiscoveryPressStyle())
        }
    }

    private func loadComments() async {
        if let all: [SocialComment] = try? await store.request("/feed/posts/\(initial.id)/comments") { latestComments = Array(all.suffix(2)) }
    }
    private var conversation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Conversazione", systemImage: "bubble.left.and.bubble.right").font(.subheadline.bold()).foregroundStyle(.black)
                Spacer()
                if post.comments > 0 { Text("\(post.comments)").font(.caption.bold()).foregroundStyle(RoamStyle.red) }
            }
            if latestComments.isEmpty {
                Text("Ancora nessun commento. Sii il primo a dire la tua.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(latestComments) { CommentRow(comment: $0, compact: true) }
            }
            Button { commenting = true } label: {
                HStack(spacing: 10) {
                    Avatar(photo: store.profile.photo, size: 28)
                    Text(post.comments > 2 ? "Apri tutta la conversazione" : "Aggiungi la tua voce…").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(RoamStyle.red)
                }.padding(.horizontal, 10).frame(height: 44).roamGlassCapsule(interactive: true)
            }.buttonStyle(DiscoveryPressStyle())
        }.padding(16).roamGlass(24)
    }

    private var placeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PlaceGlyph(category: place.category).frame(width: 22, height: 22).foregroundStyle(RoamStyle.red)
                    .frame(width: 44, height: 44).background(.white.opacity(0.7), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.headline).foregroundStyle(.black).lineLimit(2)
                    Text("\(place.category) · \(distanceLabel(place.distance)) da te").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if !place.description.isEmpty { Text(place.description).font(.subheadline).foregroundStyle(.black.opacity(0.75)).lineLimit(4) }
            HStack(spacing: 10) {
                Button { showingPlace = true } label: {
                    Label("Vedi il luogo", systemImage: "mappin.circle").frame(maxWidth: .infinity).frame(height: 42).foregroundStyle(RoamStyle.red).roamGlassCapsule()
                }.buttonStyle(DiscoveryPressStyle())
                Button { directions() } label: {
                    Label("Portami qui", systemImage: "arrow.turn.up.right").frame(maxWidth: .infinity).frame(height: 42).foregroundStyle(.white).background(RoamStyle.red, in: Capsule())
                }.buttonStyle(DiscoveryPressStyle())
            }.font(.subheadline.weight(.semibold))
        }.padding(16).roamGlass(24)
    }

    private func directions() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)); item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
    private func saveFromDoubleTap() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55)) { burst = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { withAnimation(.easeOut(duration: 0.25)) { burst = false } }
        guard !post.saved, !saving else { return }
        toggleSave()
    }
}

// Swipeable photos of a place: the given posts first, then the found web photo, then other community posts.
struct PlacePhotoGallery: View {
    let place: Place
    var leading: [SocialPost] = []
    var height: CGFloat = 440
    var radius: CGFloat = 30
    @EnvironmentObject private var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var webFailed = false
    private enum Item: Identifiable {
        case uploaded(UIImage), web(WebPhoto), post(SocialPost)
        var id: String {
            switch self { case .uploaded: "uploaded"; case .web(let w): "web-" + w.url; case .post(let p): "post-" + p.id }
        }
    }
    private var items: [Item] {
        var result: [Item] = leading.filter { $0.photo != nil }.map { .post($0) }
        if let photo = store.activity[place.id]?.photo, let data = Data(base64Encoded: photo), let image = UIImage(data: data) { result.append(.uploaded(image)) }
        if let web = store.webPhotos[place.id], !webFailed { result.append(.web(web)) }
        let shown = Set(leading.map(\.id))
        result += store.communityPhotos(place.id).filter { !shown.contains($0.id) }.map { .post($0) }
        return result
    }
    var body: some View {
        let items = items
        Group {
            if items.isEmpty { PlaceVisual(place: place, height: height) }
            else {
                TabView(selection: $page) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in photo(item).tag(index) }
                }.tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottomLeading) {
            if items.indices.contains(page), let caption = caption(items[page]) {
                Text(caption).font(.caption.weight(.semibold)).foregroundStyle(.black).lineLimit(1)
                    .padding(.horizontal, 10).padding(.vertical, 6).roamGlassCapsule().padding(12)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if items.count > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<min(items.count, 8), id: \.self) { i in
                        Capsule().fill(i == min(page, 7) ? RoamStyle.red : .black.opacity(0.25)).frame(width: i == min(page, 7) ? 16 : 6, height: 6)
                    }
                }.padding(.horizontal, 10).padding(.vertical, 8).roamGlassCapsule().padding(12)
                    .animation(reduceMotion ? nil : .spring(response: 0.3), value: page)
                    .accessibilityElement(children: .ignore).accessibilityLabel("Foto \(page + 1) di \(items.count)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .task(id: place.id) {
            await store.loadWebPhoto(place)
            await store.loadPlacePosts(place)
        }
        .onChange(of: items.count) { _, count in if page >= count { page = max(0, count - 1) } }
    }
    @ViewBuilder private func photo(_ item: Item) -> some View {
        switch item {
        case .uploaded(let image): fill(Image(uiImage: image))
        case .post(let post):
            if let image = PostImageCache.image(post) { fill(Image(uiImage: image)).accessibilityLabel("Foto di \(post.author) a \(place.name)") }
        case .web(let web):
            AsyncImage(url: URL(string: web.url)) { phase in
                if let image = phase.image { fill(image) }
                else if phase.error != nil { RoamStyle.surface.onAppear { if !store.nextWebPhoto(place) { webFailed = true } } }
                else { RoamStyle.surface.overlay { ProgressView() } }
            }.id(web.url).accessibilityLabel("Foto di \(place.name)")
        }
    }
    private func fill(_ image: Image) -> some View {
        Color.clear.overlay { image.resizable().scaledToFill() }.clipped()
    }
    private func caption(_ item: Item) -> String? {
        switch item {
        case .uploaded: "Foto della community"
        case .web(let web): web.provider == "google_images" ? "Fonte web verificata" : "Wikimedia Commons · \(web.author)"
        case .post(let post): leading.contains { $0.id == post.id } ? nil : "Foto di \(post.author)"
        }
    }
}

struct PlaceChooser: View {
    let places: [Place]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var filtered: [Place] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? places : places.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.category.localizedCaseInsensitiveContains(q) }
    }
    var body: some View {
        List(filtered) { place in
            Button { selection = place.id; dismiss() } label: {
                HStack(spacing: 12) {
                    PlaceGlyph(category: place.category).frame(width: 22, height: 22).foregroundStyle(RoamStyle.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).foregroundStyle(.primary)
                        Text("\(place.category) · \(place.distance < 1 ? "\(Int(place.distance * 1000)) m" : String(format: "%.1f km", place.distance))").font(.caption).foregroundStyle(.black)
                    }
                    Spacer()
                    if place.id == selection { Image(systemName: "checkmark").foregroundStyle(RoamStyle.red) }
                }
            }.buttonStyle(.plain).roamGlassRow()
        }
        .listStyle(.plain).roamGlassForm()
        .overlay { if filtered.isEmpty { RoamEmptyState(icon: "magnifyingglass", title: "Nessun luogo", message: "Nessun risultato per “\(query)”.") } }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca un luogo")
        .navigationTitle("Aggiungi luogo").roamHeader()
    }
}

struct SocialComposer: View {
    let places: [Place]
    let onPublished: (SocialPost) -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var placeID = ""
    @State private var caption = ""
    @State private var rating = 5
    @State private var selection: PhotosPickerItem?
    @State private var photo: String?
    @State private var loadingPhoto = false
    @State private var publishing = false
    @State private var failure: String?
    private var place: Place? { places.first { $0.id == placeID } }
    private var valid: Bool { !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && caption.count <= 2000 && photo != nil && place != nil }
    var body: some View {
        NavigationStack {
            Form { Group {
                Section {
                    PhotosPicker(selection: $selection, matching: .images) {
                        ZStack {
                            if let photo, let data = Data(base64Encoded: photo), let image = UIImage(data: data) {
                                Color.clear.aspectRatio(4 / 5, contentMode: .fit).overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(RoamStyle.red)
                                    Text("Scegli una foto").font(.headline).foregroundStyle(.primary)
                                }.frame(maxWidth: .infinity).frame(height: 240)
                            }
                            if loadingPhoto { ProgressView().controlSize(.large) }
                        }
                    }.disabled(publishing || loadingPhoto).listRowInsets(EdgeInsets())
                } footer: { if photo != nil { Text("Tocca la foto per cambiarla.") } }
                Section {
                    TextField("Scrivi una didascalia…", text: $caption, axis: .vertical).lineLimit(3...8)
                    Text("\(caption.count)/2000").font(.caption).foregroundStyle(caption.count > 2000 ? RoamStyle.red : .black)
                }
                Section {
                    if places.isEmpty { Text("Esplora la mappa per caricare i luoghi vicini: ogni post è collegato a un luogo.").foregroundStyle(.black) }
                    else {
                        NavigationLink { PlaceChooser(places: places, selection: $placeID) } label: {
                            HStack {
                                Label(place?.name ?? "Aggiungi luogo", systemImage: place == nil ? "mappin.and.ellipse" : "mappin.circle.fill")
                                    .foregroundStyle(place == nil ? RoamStyle.red : .primary)
                                Spacer()
                                if place == nil { Text("Obbligatorio").font(.caption).foregroundStyle(.black) }
                            }
                        }
                    }
                    Picker("Valutazione", selection: $rating) { ForEach(1...5, id: \.self) { Text(String(repeating: "★", count: $0)).tag($0) } }
                } header: { Text("Luogo") } footer: {
                    Text("Ogni post è legato a un luogo. Pubblicato come \(store.profile.name); foto e testo vengono salvati sul backend di Roam.")
                }
                if let failure { Section { Text(failure).foregroundStyle(.red) } }
            }.listRowBackground(GlassRowBackground())
}.disabled(publishing).roamGlassForm().listSectionSeparator(.hidden).tint(RoamStyle.red)
                .navigationTitle("Nuovo post").roamHeader()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(publishing) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { publish() } label: { if publishing { ProgressView() } else { Text("Condividi").bold() } }.disabled(!valid || publishing || loadingPhoto)
                    }
                }.interactiveDismissDisabled(publishing || loadingPhoto)
                .onChange(of: selection) { _, item in
                    Task {
                        loadingPhoto = true; defer { loadingPhoto = false }
                        do {
                            guard let data = try await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                            let ratio = min(1, 1200 / max(image.size.width, image.size.height))
                            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                            let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                            guard let jpeg = resized.jpegData(compressionQuality: 0.75) else { throw URLError(.cannotDecodeContentData) }
                            photo = jpeg.base64EncodedString(); failure = nil
                        } catch { failure = "Foto non leggibile. Scegli un’altra immagine." }
                    }
                }
        }
    }
    private func publish() {
        guard let place, let photo else { return }
        publishing = true; failure = nil
        Task {
            defer { publishing = false }
            do {
                try await store.register(place)
                let payload = try JSONSerialization.data(withJSONObject: ["place_id": place.id, "body": caption, "rating": rating, "photo": photo])
                let post: SocialPost = try await store.request("/feed/posts", method: "POST", body: payload)
                store.published(post)
                onPublished(post); dismiss()
            } catch { failure = error.localizedDescription }
        }
    }
}

// One comment: portrait, name and time, then the text. Own comments carry a red accent.
struct CommentRow: View {
    let comment: SocialComment
    var compact = false
    var onAuthor: ((Person) -> Void)? = nil
    @EnvironmentObject private var store: Store
    private var mine: Bool { comment.mine == true }
    private var person: Person? {
        guard !mine, let key = comment.author_key else { return nil }
        return Person(key: key, name: comment.author, photo: comment.author_photo)
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { if let person { onAuthor?(person) } } label: {
                Avatar(photo: mine ? store.profile.photo : comment.author_photo, size: compact ? 32 : 40)
                    .overlay(Circle().stroke(mine ? RoamStyle.red : .white.opacity(0.8), lineWidth: 2))
            }.buttonStyle(.plain).disabled(person == nil || onAuthor == nil).accessibilityLabel("Profilo di \(comment.author)")
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(mine ? store.profile.name : comment.author).font(.subheadline.bold()).foregroundStyle(.black).lineLimit(1)
                    if mine { Text("Tu").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(RoamStyle.red, in: Capsule()) }
                    Spacer(minLength: 4)
                    Text(postDateLabel(comment.created_at)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(comment.body).font(compact ? .footnote : .subheadline).foregroundStyle(.black.opacity(0.85))
                    .lineLimit(compact ? 2 : nil).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
        }
        .padding(compact ? 12 : 14).frame(maxWidth: .infinity, alignment: .leading)
        .roamGlass(compact ? 18 : 22)
        .overlay(alignment: .leading) { if mine { Capsule().fill(RoamStyle.red).frame(width: 3).padding(.vertical, 14) } }
        .accessibilityElement(children: .combine)
    }
}

struct SocialCommentsView: View {
    let post: SocialPost
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [SocialComment] = []
    @State private var text = ""
    @State private var loading = true
    @State private var sending = false
    @State private var failure: String?
    @State private var person: Person?
    @FocusState private var focused: Bool
    private var image: UIImage? { PostImageCache.image(post) }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Group {
                                if let image { Image(uiImage: image).resizable().scaledToFill() }
                                else { PlaceVisual(place: post.place, height: 64) }
                            }.frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Label(post.place.name, systemImage: "mappin").font(.subheadline.bold()).foregroundStyle(.black).lineLimit(1)
                                Text(post.body).font(.caption).foregroundStyle(.black.opacity(0.7)).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }.padding(12).roamGlass(24)
                        HStack {
                            Text(comments.isEmpty ? "Conversazione" : comments.count == 1 ? "1 voce nella conversazione" : "\(comments.count) voci nella conversazione")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(0.4)
                            Spacer()
                        }.padding(.horizontal, 6).padding(.top, 6)
                        if loading && comments.isEmpty { ProgressView("Carico i commenti…").padding(30) }
                        else if comments.isEmpty && failure == nil {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.text.bubble.right").font(.system(size: 34)).foregroundStyle(RoamStyle.red)
                                Text("Nessuno ha ancora risposto").font(.headline).foregroundStyle(.black)
                                Text("Racconta com’è andata la tua visita o fai una domanda a chi ha pubblicato.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }.padding(24).frame(maxWidth: .infinity).roamGlass(24)
                        }
                        ForEach(comments) { comment in
                            CommentRow(comment: comment) { person = $0 }.id(comment.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if let failure {
                            VStack(spacing: 8) { Text(failure).font(.subheadline).foregroundStyle(RoamStyle.red); Button("Riprova") { Task { await load() } } }
                                .padding(16).frame(maxWidth: .infinity).roamGlass(20)
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: comments.last?.id) { _, id in if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .background {
                ZStack {
                    RoamStyle.canvas
                    if let image { Image(uiImage: image).resizable().scaledToFill().blur(radius: 70).opacity(0.5) }
                    Color.white.opacity(0.35)
                }.ignoresSafeArea()
            }
            .navigationTitle("Commenti").navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() }.foregroundStyle(RoamStyle.red) } }
            .task { await load() }
            .sheet(item: $person) { PersonSheet(person: $0) }
        }
    }
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Avatar(photo: store.profile.photo, size: 34).padding(.bottom, 4)
            TextField("Aggiungi la tua voce…", text: $text, axis: .vertical).lineLimit(1...5).focused($focused)
                .padding(.vertical, 10)
            Button { send() } label: {
                Group { if sending { ProgressView().tint(.white) } else { Image(systemName: "arrow.up").font(.headline) } }
                    .foregroundStyle(.white).frame(width: 38, height: 38).background(RoamStyle.red, in: Circle())
            }
            .disabled(sending || loading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 1000)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .padding(.bottom, 2).accessibilityLabel("Pubblica commento")
        }
        .padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 6)
        .roamGlass(26).padding(.horizontal, 12).padding(.bottom, 8)
    }
    private func load() async {
        loading = true; defer { loading = false }
        do { comments = try await store.request("/feed/posts/\(post.id)/comments"); failure = nil }
        catch { failure = "Commenti non disponibili. Riprova." }
    }
    private func send() {
        sending = true
        Task {
            defer { sending = false }
            do {
                let payload = try JSONSerialization.data(withJSONObject: ["body": text])
                let comment: SocialComment = try await store.request("/feed/posts/\(post.id)/comments", method: "POST", body: payload)
                withAnimation(.spring(response: 0.35)) { comments.append(comment) }
                text = ""; failure = nil
                store.updatePost(post.id) { $0.comments = comments.count }
            } catch { failure = "Invio non riuscito. Il testo è conservato: riprova." }
        }
    }
}

// Home card: full-bleed photo, glass caption with the place and its actions.
struct PlaceFeedCard: View {
    let place: Place
    let onOpen: () -> Void
    let onMap: () -> Void
    @EnvironmentObject private var store: Store
    var body: some View {
        // A tap gesture (not an outer Button) so the inner Mappa/Indicazioni buttons stay tappable.
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                PlaceVisual(place: place, height: 290).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(place.name).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(.black).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        if let rating = store.activity[place.id]?.rating {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill").font(.caption.bold()).foregroundStyle(RoamStyle.red)
                        }
                    }
                    Text(place.description).font(.footnote).foregroundStyle(.black.opacity(0.7)).lineLimit(2).multilineTextAlignment(.leading)
                    HStack(spacing: 12) {
                        Label("\(distanceLabel(place.distance)) da te", systemImage: "location")
                        Label(store.activity[place.id].map { "\($0.comments)" } ?? "0", systemImage: "bubble.left")
                        Spacer(minLength: 0)
                    }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button(action: onMap) {
                            Label("Mappa", systemImage: "map").frame(maxWidth: .infinity).frame(height: 38).foregroundStyle(RoamStyle.red).roamGlassCapsule(interactive: true)
                        }.buttonStyle(DiscoveryPressStyle())
                        Button {
                            let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)); item.name = place.name
                            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                        } label: {
                            Label("Indicazioni", systemImage: "arrow.turn.up.right").frame(maxWidth: .infinity).frame(height: 38).foregroundStyle(.white).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                        }.buttonStyle(DiscoveryPressStyle())
                    }.font(.subheadline.weight(.semibold))
                }.padding(14).roamGlass(24).padding(10)
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 6) { PlaceGlyph(category: place.category).frame(width: 15, height: 15); Text(place.category).font(.caption.bold()) }
                    .foregroundStyle(RoamStyle.red).padding(.horizontal, 12).padding(.vertical, 8).roamGlassCapsule().padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        }
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(place.name), \(place.category), \(distanceLabel(place.distance)) da te")
        .accessibilityAction(named: "Apri il luogo", onOpen)
        .task(id: place.id) { await store.refreshActivity(place) }
    }
}
struct PlaceCard: View {
    let place: Place
    @EnvironmentObject var store: Store
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PlaceVisual(place: place, height: 360, prominent: true)
            LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .black.opacity(0.85), location: 1)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 12) {
                Text(place.name).font(.system(.title, design: .rounded, weight: .bold)).tracking(-0.8).foregroundStyle(.white).lineLimit(2)
                HStack(spacing: 7) {
                    Image(systemName: "location").font(.caption)
                    Text(String(format: "%.1f km da te", place.distance)).font(.subheadline)
                    if let rating = store.activity[place.id]?.rating {
                        Text("·"); Image(systemName: "star.fill").font(.caption); Text(String(format: "%.1f", rating)).font(.subheadline.bold())
                    }
                }.foregroundStyle(.white.opacity(0.85))
                HStack {
                    Label(store.activity[place.id].map { "\($0.comments) commenti" } ?? "Scopri il luogo", systemImage: "bubble.left").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.headline).foregroundStyle(.black).frame(width: 44, height: 44).background(.white, in: Circle())
                }
            }.padding(22)
        }.overlay(alignment: .topLeading) {
            HStack(spacing: 6) { PlaceGlyph(category: place.category).frame(width: 16, height: 16); Text(place.category).font(.caption.bold()) }
                .foregroundStyle(.white).padding(.horizontal, 13).padding(.vertical, 9).background(RoamStyle.red, in: Capsule()).padding(16)
        }.clipShape(RoundedRectangle(cornerRadius: 30))
            .contentShape(RoundedRectangle(cornerRadius: 30))
            .task(id: place.id) { await store.refreshActivity(place) }
    }
}
struct PlaceView: View {
    let place: Place
    @EnvironmentObject var store: Store
    @State private var reviews: [Review] = []
    @State private var bodyText = ""
    @State private var rating = 5
    @State private var sending = false
    @State private var placePhoto: PhotosPickerItem?
    @State private var savingPhoto = false
    @State private var reviewError: String?
    @State private var openedPostID: String?
    @FocusState private var writing: Bool
    private var posts: [SocialPost] { store.placePosts[place.id] ?? [] }
    private var canPublish: Bool { !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PlacePhotoGallery(place: place, height: 320, radius: 30)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) { PlaceGlyph(category: place.category).frame(width: 15, height: 15); Text(place.category).font(.caption.bold()) }
                            .foregroundStyle(RoamStyle.red).padding(.horizontal, 12).padding(.vertical, 8).roamGlassCapsule().padding(12)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
                header
                mapCard
                if !posts.isEmpty { experiences }
                conversation
                if let photo = store.webPhotos[place.id], let url = URL(string: photo.source_url) {
                    Link(destination: url) { Label("Foto: \(photo.author) · \(photo.license)", systemImage: "info.circle").font(.caption2) }
                        .foregroundStyle(.secondary).padding(.horizontal, 6)
                }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { GlassBackdrop() }.navigationTitle(place.name).navigationBarTitleDisplayMode(.inline).roamHeader()
        .navigationDestination(item: $openedPostID) { id in
            if let post = posts.first(where: { $0.id == id }) { SocialPostDetailView(initial: post, place: place) }
        }
            .task {
                await store.refreshActivity(place)
                do { try await store.register(place); store.track(view: place); reviews = try await store.request("/places/\(place.id)/comments") }
                catch { reviewError = "Commenti non disponibili. Controlla la connessione al backend." }
            }
            .onChange(of: placePhoto) { _, item in
                Task {
                    savingPhoto = true; defer { savingPhoto = false }
                    do {
                        guard let data = try await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                        let ratio = min(1, 1200 / max(image.size.width, image.size.height))
                        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                        guard let jpeg = resized.jpegData(compressionQuality: 0.75) else { return }
                        try await store.register(place)
                        let payload = try JSONSerialization.data(withJSONObject: ["photo": jpeg.base64EncodedString()])
                        let activity: PlaceActivity = try await store.request("/places/\(place.id)/photo", method: "PUT", body: payload)
                        store.activity[place.id] = activity
                    } catch { store.error = error.localizedDescription }
                }
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(place.name).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.black)
            HStack(spacing: 12) {
                Label("\(distanceLabel(place.distance)) da te", systemImage: "location")
                if let rating = store.activity[place.id]?.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill").foregroundStyle(RoamStyle.red)
                }
                Label("\(store.activity[place.id]?.comments ?? reviews.count)", systemImage: "bubble.left")
            }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if !place.description.isEmpty {
                Text(place.description).font(.subheadline).foregroundStyle(.black.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button { directions() } label: {
                    Label("Portami qui", systemImage: "arrow.turn.up.right").frame(maxWidth: .infinity).frame(height: 44)
                        .foregroundStyle(.white).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                }.buttonStyle(DiscoveryPressStyle())
                PhotosPicker(selection: $placePhoto, matching: .images) {
                    Group { if savingPhoto { ProgressView() } else { Label("Aggiungi foto", systemImage: "camera") } }
                        .frame(maxWidth: .infinity).frame(height: 44).foregroundStyle(RoamStyle.red).roamGlassCapsule(interactive: true)
                }.disabled(savingPhoto).buttonStyle(DiscoveryPressStyle()).accessibilityHint("La foto diventa la copertina del luogo")
                ShareLink(item: "\(place.name) — \(place.description)") {
                    Image(systemName: "square.and.arrow.up").font(.headline).foregroundStyle(RoamStyle.red).frame(width: 44, height: 44).roamGlassCircle(interactive: true)
                }.accessibilityLabel("Condividi il luogo")
            }.font(.subheadline.weight(.semibold))
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).roamGlass(26)
    }

    private var mapCard: some View {
        Map(initialPosition: .region(.init(center: place.coordinate, span: .init(latitudeDelta: 0.012, longitudeDelta: 0.012)))) {
            Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) { RoamMapPin(place: place, selected: true) }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Label(place.description.isEmpty ? "\(distanceLabel(place.distance)) da te" : place.description, systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.semibold)).foregroundStyle(.black).lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 6).roamGlassCapsule().padding(10)
        }
        .padding(8).roamGlass(28)
    }

    private var experiences: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Esperienze qui", systemImage: "photo.on.rectangle").font(.headline).foregroundStyle(.black)
                Spacer()
                Text("\(posts.count)").font(.caption.bold()).foregroundStyle(RoamStyle.red)
            }.padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(posts.prefix(12)) { post in
                        SocialPostPreview(post: post, place: place, compact: true) { openedPostID = post.id }.frame(width: 240)
                    }
                }.padding(.vertical, 4).padding(.horizontal, 2)
            }
        }
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Commenti della community", systemImage: "bubble.left.and.bubble.right").font(.headline).foregroundStyle(.black)
                Spacer()
                if !reviews.isEmpty { Text("\(reviews.count)").font(.caption.bold()).foregroundStyle(RoamStyle.red) }
            }
            if let reviewError { Label(reviewError, systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.secondary) }
            if reviews.isEmpty && reviewError == nil {
                Text("Nessun commento ancora. Racconta per primo com’è andata.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(reviews) { review in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(review.author.prefix(1)).uppercased()).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(RoamStyle.red)
                        .frame(width: 38, height: 38).roamGlassCircle()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(review.author).font(.subheadline.bold()).foregroundStyle(.black).lineLimit(1)
                            Spacer(minLength: 4)
                            RatingStars(rating: review.rating)
                        }
                        Text(review.body).font(.subheadline).foregroundStyle(.black.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).roamGlass(20)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Avatar(photo: store.profile.photo, size: 30)
                    Text("La tua valutazione").font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star").font(.title3).foregroundStyle(RoamStyle.red)
                            }.buttonStyle(.plain).accessibilityLabel("\(value) stelle")
                        }
                    }.accessibilityElement(children: .contain).accessibilityValue("\(rating) su 5")
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Com’è stata la tua visita?", text: $bodyText, axis: .vertical).lineLimit(1...6).focused($writing)
                        .padding(.vertical, 11).padding(.leading, 14)
                    Button { publish() } label: {
                        Group { if sending { ProgressView().tint(.white) } else { Image(systemName: "arrow.up").font(.headline) } }
                            .foregroundStyle(.white).frame(width: 36, height: 36).background(RoamStyle.red, in: Circle())
                    }.disabled(!canPublish).opacity(canPublish ? 1 : 0.45).padding(.trailing, 5).padding(.bottom, 4).accessibilityLabel("Pubblica commento")
                }.roamGlass(22)
            }.padding(.top, 4)
        }.padding(16).roamGlass(26)
    }

    private func directions() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)); item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
    private func publish() {
        sending = true
        Task {
            defer { sending = false }
            do {
                try await store.register(place)
                let data = try JSONSerialization.data(withJSONObject: ["author": store.profile.name, "body": bodyText, "rating": rating])
                let review: Review = try await store.request("/places/\(place.id)/comments", method: "POST", body: data)
                withAnimation(.spring(response: 0.35)) { reviews.insert(review, at: 0) }
                bodyText = ""; reviewError = nil; writing = false
                await store.refreshActivity(place)
                store.stats = try await store.request("/stats")
            } catch { store.error = error.localizedDescription }
        }
    }
}
struct SearchActivity: Identifiable, Hashable {
    let title, query, category, icon: String
    var id: String { title }
    static let all = [
        SearchActivity(title: "Musei e cultura", query: "musei", category: "Attrazione", icon: "building.columns.fill"),
        SearchActivity(title: "Monumenti", query: "monumenti e siti storici", category: "Attrazione", icon: "building.columns"),
        SearchActivity(title: "Panorami", query: "punti panoramici", category: "Attrazione", icon: "binoculars.fill"),
        SearchActivity(title: "Parchi e natura", query: "parchi e giardini", category: "Parco", icon: "leaf.fill"),
        SearchActivity(title: "Mangiare fuori", query: "ristoranti", category: "Ristorante", icon: "fork.knife"),
        SearchActivity(title: "Pizza", query: "pizzerie", category: "Ristorante", icon: "flame.fill"),
        SearchActivity(title: "Caffè e colazioni", query: "caffè", category: "Caffè", icon: "cup.and.saucer.fill"),
        SearchActivity(title: "Gelato e dolci", query: "gelaterie e pasticcerie", category: "Caffè", icon: "birthday.cake.fill"),
        SearchActivity(title: "Shopping", query: "negozi", category: "Negozio", icon: "bag.fill"),
        SearchActivity(title: "Librerie e mercati", query: "librerie e mercati", category: "Negozio", icon: "books.vertical.fill")
    ]
}
struct SearchPlaceRow: View {
    let place: Place
    private var distance: String { place.distance < 1 ? "\(Int(place.distance * 1000)) m" : String(format: "%.1f km", place.distance) }
    var body: some View {
        HStack(spacing: 14) {
            PlaceGlyph(category: place.category).frame(width: 22, height: 22).foregroundStyle(RoamStyle.red)
                .frame(width: 48, height: 48).background(RoamStyle.red.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                Text("\(place.category == "Attrazione" ? "Da vedere" : place.category == "Negozio" ? "Shopping" : place.category) · \(distance)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }.padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
    }
}
struct PersonBadge: View {
    let person: Person
    var size: CGFloat = 48
    @EnvironmentObject private var store: Store
    var body: some View {
        if person.is_roam { RoamAvatar(size: size) }
        else if person.mine { Avatar(photo: store.profile.photo, size: size) }
        else if person.photo != nil { Avatar(photo: person.photo, size: size) }
        else {
            Text(String(person.name.prefix(1)).uppercased()).font(.system(size: size * 0.4, weight: .bold, design: .rounded)).foregroundStyle(RoamStyle.red)
                .frame(width: size, height: size).background(RoamStyle.red.opacity(0.08), in: Circle())
        }
    }
}
struct PersonRow: View {
    let person: Person
    @EnvironmentObject private var store: Store
    var body: some View {
        HStack(spacing: 14) {
            PersonBadge(person: person)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(person.name).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                    if person.mine { Text("Tu").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(RoamStyle.red, in: Capsule()) }
                }
                Text("\(person.posts) \(person.posts == 1 ? "esperienza" : "esperienze") · \(person.places) \(person.places == 1 ? "luogo" : "luoghi")").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }.padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
    }
}
struct SearchView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var location: LocationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scope = "Luoghi"
    @State private var query = ""
    @State private var activity: SearchActivity?
    @State private var appleResults: [Place] = []
    @State private var searching = false
    @State private var searchFailure: String?
    @State private var people: [Person] = []
    @State private var peopleLoaded = false
    @State private var peopleError: String?
    @State private var openedPlace: Place?
    @State private var city: CityResult?
    @State private var cityPlaces: [Place] = []
    @State private var cityPosts: [SocialPost] = []
    @State private var cityLoading = false
    @State private var cityNote: String?
    @State private var cityCategory = "Tutti"
    @State private var openedPostID: String?
    @FocusState private var fieldFocused: Bool
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var placeResults: [Place] {
        var seen = Set<String>()
        let local = store.knownPlaces.filter { place in
            if scope == "Attività" { return activity.map { place.category == $0.category } ?? false }
            return trimmed.isEmpty || place.name.localizedCaseInsensitiveContains(trimmed) || place.category.localizedCaseInsensitiveContains(trimmed) || place.description.localizedCaseInsensitiveContains(trimmed)
        }
        return (appleResults + local).filter { seen.insert($0.id).inserted }.sorted { $0.distance < $1.distance }
    }
    private var activities: [SearchActivity] {
        trimmed.isEmpty ? SearchActivity.all : SearchActivity.all.filter { $0.title.localizedCaseInsensitiveContains(trimmed) || $0.query.localizedCaseInsensitiveContains(trimmed) }
    }
    private var searchKey: String { scope + "|" + trimmed + "|" + (activity?.id ?? "") + "|" + String(store.appleSearchEnabled) + "|" + (location.coordinate.map { "\(Int($0.latitude * 100)),\(Int($0.longitude * 100))" } ?? "") }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CERCA").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(RoamStyle.red)
                        Text("Trova il tuo\nprossimo posto.").font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1.4).lineSpacing(-3)
                    }.padding(.horizontal, 24)
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").foregroundStyle(RoamStyle.red)
                        TextField(scope == "Persone" ? "Cerca viaggiatori" : scope == "Attività" ? "Cosa ti va di fare?" : "Cerca città, paesi e luoghi", text: $query)
                            .font(.subheadline).submitLabel(.search).autocorrectionDisabled().focused($fieldFocused)
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("Cancella ricerca")
                        }
                    }.padding(.horizontal, 18).padding(.vertical, 15).roamGlassCapsule().padding(.horizontal, 24)
                    RoamTabs(options: ["Luoghi", "Attività", "Persone"], selection: $scope).padding(.horizontal, 16)
                    switch scope {
                    case "Persone": peopleSection
                    case "Attività": activitySection
                    default: placesSection
                    }
                }.padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively).background { GlassBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Person.self) { PersonView(person: $0) }
            .sheet(item: $openedPlace) { PlaceSheet(place: $0) }
            .navigationDestination(item: $openedPostID) { id in
                if let post = cityPosts.first(where: { $0.id == id }) {
                    SocialPostDetailView(initial: post, place: cityPlaces.first { $0.id == post.place_id } ?? post.place)
                }
            }
            .onChange(of: scope) { _, _ in appleResults = []; searchFailure = nil }
            .task(id: searchKey) {
                do { try await Task.sleep(for: .milliseconds(trimmed.isEmpty ? 0 : 350)); try Task.checkCancellation() } catch { return }
                async let cityLookup: Void = searchCity()
                await runSearch()
                await cityLookup
            }
        }
    }
    @ViewBuilder private var placesSection: some View {
        // A destination does not need the phone's position: Tokyo and Spagna resolve on their own.
        if let city { citySection(city) }
        else if cityLoading { HStack(spacing: 10) { ProgressView(); Text("Cerco la destinazione…").font(.subheadline).foregroundStyle(.secondary) }.padding(.horizontal, 24) }
        else if trimmed.count >= 3, let cityNote { Text(cityNote).font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 24) }
        if location.coordinate == nil && store.knownPlaces.isEmpty {
            if city == nil {
                RoamEmptyState(icon: "location.magnifyingglass", title: "Dove ti trovi?", message: "Attiva la posizione per cercare luoghi e attrazioni vicino a te. Puoi comunque cercare una città o un paese.", action: "Usa la mia posizione") { location.request() }.padding(.top, 24)
            }
        } else {
            resultsHeader(trimmed.isEmpty ? "VICINO A TE" : city == nil ? "RISULTATI" : "ALTRI RISULTATI")
            placeList
            appleHint
        }
    }
    private var cityCategories: [String] {
        let present = Set(cityPlaces.map(\.category))
        return ["Tutti"] + ["Attrazione", "Ristorante", "Caffè", "Parco", "Negozio"].filter(present.contains)
    }
    private var filteredCityPlaces: [Place] { cityCategory == "Tutti" ? cityPlaces : cityPlaces.filter { $0.category == cityCategory } }
    @ViewBuilder private func citySection(_ city: CityResult) -> some View {
        let km = location.coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)) / 1000 }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CITTÀ").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(RoamStyle.red)
                    Text(city.name).font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(.black).lineLimit(1).minimumScaleFactor(0.6)
                    Text([city.region, city.country].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "building.2.crop.circle").font(.system(size: 30)).foregroundStyle(RoamStyle.red).frame(width: 56, height: 56).roamGlassCircle()
            }
            HStack(spacing: 8) {
                if let km { Label(km < 1 ? "Sei qui" : km < 10 ? String(format: "%.1f km da te", km) : "\(Int(km)) km da te", systemImage: "location") }
                Label("\(cityPlaces.count) luoghi", systemImage: "mappin.and.ellipse").contentTransition(.numericText())
                Label("\(cityPosts.count) esperienze", systemImage: "photo.on.rectangle").contentTransition(.numericText())
                if cityLoading { ProgressView().controlSize(.small).accessibilityLabel("Carico altri luoghi") }
            }.font(.caption.weight(.semibold)).foregroundStyle(.black.opacity(0.7)).labelStyle(.titleAndIcon)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Stays inside the card: never draws over the search field above.
            ZStack {
                if let image = cityPosts.lazy.compactMap({ PostImageCache.image($0) }).first {
                    Image(uiImage: image).resizable().scaledToFill().blur(radius: 30).opacity(0.55)
                } else {
                    LinearGradient(colors: [RoamStyle.red.opacity(0.16), Color(red: 1, green: 0.95, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                Color.white.opacity(0.45)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
        .padding(.horizontal, 24)
        if !cityPosts.isEmpty {
            resultsHeader("ESPERIENZE A \(city.name.uppercased())")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(cityPosts.prefix(20)) { post in
                        SocialPostPreview(post: post, place: cityPlaces.first { $0.id == post.place_id } ?? post.place, compact: true) { openedPostID = post.id }.frame(width: 250)
                    }
                }.padding(.horizontal, 24).padding(.vertical, 4)
            }
        }
        if !cityPlaces.isEmpty {
            resultsHeader("DA SCOPRIRE A \(city.name.uppercased()) · DAL CENTRO")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cityCategories, id: \.self) { category in
                        Button { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { cityCategory = category } } label: {
                            Text(category).font(.subheadline.weight(.semibold)).foregroundStyle(cityCategory == category ? .white : .black)
                                .padding(.horizontal, 14).frame(height: 36)
                                .roamGlassCapsule(interactive: true, tint: cityCategory == category ? RoamStyle.red : nil)
                        }.buttonStyle(.plain).accessibilityAddTraits(cityCategory == category ? .isSelected : [])
                    }
                }.padding(.horizontal, 24)
            }
            let shown = Array(filteredCityPlaces.prefix(30))
            LazyVStack(spacing: 0) {
                ForEach(shown) { place in
                    Button { openedPlace = place } label: { SearchPlaceRow(place: place) }.buttonStyle(.plain)
                    if place.id != shown.last?.id { Divider().padding(.leading, 78) }
                }
            }.roamGlass(26).padding(.horizontal, 24)
        } else if !cityLoading {
            Text("Nessun luogo caricato per \(city.name) al momento. Riprova tra poco.").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 24)
        }
    }
    private func searchCity() async {
        guard scope == "Luoghi", trimmed.count >= 3 else { city = nil; cityPlaces = []; cityPosts = []; cityNote = nil; return }
        cityLoading = true; defer { cityLoading = false }
        let outcome = await store.geocodeOutcome(trimmed)
        guard let found = outcome.place, !Task.isCancelled else {
            if !Task.isCancelled {
                city = nil; cityPlaces = []; cityPosts = []
                cityNote = outcome.failure ?? "Non trovo “\(trimmed)”. Prova con la città, la regione o il paese."
            }
            return
        }
        cityNote = nil
        if found == city && !cityPlaces.isEmpty { return }
        city = found; cityCategory = "Tutti"; cityPlaces = []; cityPosts = []
        async let osm = store.cityBackendPlaces(found)
        let maps = await store.cityMapsPlaces(found)
        guard !Task.isCancelled else { return }
        merge(maps)
        cityPosts = await store.cityPosts(cityPlaces)
        let rich = await osm
        guard !Task.isCancelled, city == found else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { merge(rich) }
        let posts = await store.cityPosts(cityPlaces)
        if !Task.isCancelled, city == found { cityPosts = posts }
        if cityPlaces.isEmpty { searchFailure = "Luoghi di \(found.name) non disponibili. Riprova tra poco." }
    }
    // OpenStreetMap entries replace Apple duplicates with the same name.
    private func merge(_ found: [Place]) {
        var byName = Dictionary(cityPlaces.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        for place in found where byName[place.name.lowercased()] == nil || place.id.hasPrefix("osm-") { byName[place.name.lowercased()] = place }
        cityPlaces = byName.values.sorted { $0.distance < $1.distance }
    }
    @ViewBuilder private var activitySection: some View {
        if let activity {
            HStack(spacing: 10) {
                Image(systemName: activity.icon).foregroundStyle(.white)
                Text(activity.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Button { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { self.activity = nil; appleResults = [] } } label: {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                }.accessibilityLabel("Scegli un’altra attività")
            }.padding(.horizontal, 16).padding(.vertical, 12).background(RoamStyle.red, in: Capsule()).padding(.horizontal, 24)
            resultsHeader("NEI DINTORNI")
            placeList
            appleHint
        } else if activities.isEmpty {
            RoamEmptyState(icon: "sparkle.magnifyingglass", title: "Nessuna attività trovata", message: "Prova con un’altra parola, ad esempio musei, pizza o parchi.").padding(.top, 24)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(activities) { item in
                    Button { fieldFocused = false; query = ""; withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { activity = item } } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: item.icon).font(.title3).foregroundStyle(RoamStyle.red)
                                .frame(width: 44, height: 44).background(RoamStyle.red.opacity(0.08), in: Circle())
                            Text(item.title).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(2)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .roamGlass(22, interactive: true)
                    }.buttonStyle(DiscoveryPressStyle())
                }
            }.padding(.horizontal, 24)
        }
    }
    @ViewBuilder private var peopleSection: some View {
        if let peopleError {
            VStack(alignment: .leading, spacing: 10) {
                Label(peopleError, systemImage: "wifi.exclamationmark").font(.subheadline)
                Button("Riprova") { Task { await runSearch() } }
            }.padding().frame(maxWidth: .infinity, alignment: .leading).roamGlass(20).padding(.horizontal, 24)
        } else if people.isEmpty && peopleLoaded {
            RoamEmptyState(icon: "person.2", title: trimmed.isEmpty ? "Ancora nessun viaggiatore" : "Nessuno con questo nome", message: trimmed.isEmpty ? "Chi pubblica un’esperienza nel Feed apparirà qui." : "Controlla il nome o prova solo con l’iniziale.").padding(.top, 24)
        } else if !peopleLoaded {
            ProgressView().frame(maxWidth: .infinity).padding(40)
        } else {
            resultsHeader(trimmed.isEmpty ? "VIAGGIATORI ATTIVI" : "VIAGGIATORI")
            LazyVStack(spacing: 0) {
                ForEach(people) { person in
                    NavigationLink(value: person) { PersonRow(person: person) }.buttonStyle(.plain)
                    if person.id != people.last?.id { Divider().padding(.leading, 78) }
                }
            }.roamGlass(26).padding(.horizontal, 24)
        }
    }
    private func resultsHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(RoamStyle.red)
            Spacer()
            if searching || store.loading { ProgressView() }
        }.padding(.horizontal, 24)
    }
    @ViewBuilder private var placeList: some View {
        let results = Array(placeResults.prefix(60))
        if results.isEmpty && !searching {
            RoamEmptyState(icon: "mappin.slash", title: "Nessun luogo trovato", message: trimmed.isEmpty && activity == nil ? "Sposta la mappa in Esplora per caricare luoghi in un’altra zona." : "Prova un’altra ricerca o esplora la mappa.").padding(.top, 16)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(results) { place in
                    Button { openedPlace = place } label: { SearchPlaceRow(place: place) }.buttonStyle(.plain)
                    if place.id != results.last?.id { Divider().padding(.leading, 78) }
                }
            }.roamGlass(26).padding(.horizontal, 24)
        }
        if let searchFailure { Label(searchFailure, systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24) }
    }
    @ViewBuilder private var appleHint: some View {
        if !store.appleSearchEnabled && location.coordinate != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cerca anche con Mappe Apple").font(.headline)
                Text("Per cercare oltre i luoghi già caricati, la ricerca invia ad Apple il testo e la tua zona. Puoi disattivarla nel profilo.").font(.caption).foregroundStyle(.secondary)
                Button("Attiva ricerca con Mappe Apple") { store.appleSearchEnabled = true }.buttonStyle(.borderedProminent).tint(RoamStyle.red)
            }.padding().roamGlass(20).padding(.horizontal, 24)
        }
    }
    private func runSearch() async {
        searchFailure = nil
        if scope == "Persone" {
            do { people = try await store.searchPeople(trimmed); peopleError = nil }
            catch { if !Task.isCancelled { peopleError = "Viaggiatori non disponibili. Controlla la connessione." } }
            if !Task.isCancelled { peopleLoaded = true }
            return
        }
        let text = scope == "Attività" ? activity?.query ?? "" : trimmed
        guard !text.isEmpty, store.appleSearchEnabled, let coordinate = location.coordinate else { appleResults = []; return }
        searching = true
        defer { searching = false }
        do {
            let found = try await store.searchPlaces(text, near: coordinate, category: scope == "Attività" ? activity?.category : nil)
            try Task.checkCancellation()
            appleResults = scope == "Attività" ? found.filter { $0.distance <= 20 } : found
        } catch { if !Task.isCancelled { appleResults = []; searchFailure = "Mappe Apple non risponde: mostro i luoghi già caricati." } }
    }
}
struct PersonView: View {
    let person: Person
    @EnvironmentObject private var store: Store
    @State private var detail: Person?
    @State private var loaded = false
    @State private var failure: String?
    @State private var openedPostID: String?
    @State private var followBusy = false
    @State private var chat: Conversation?
    @State private var opening = false
    @State private var list: String?
    private var shown: Person { detail ?? person }
    private var posts: [SocialPost] { store.personFeed.filter { $0.author_key == person.key } }
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ProfileHero(name: shown.name, bio: shown.bio, notes: (shown.is_demo ? ["Profilo dimostrativo · persona fittizia"] : []) + (shown.follows_you ? ["Ti segue"] : [])) {
                    PersonBadge(person: shown, size: 104)
                } stats: {
                    ProfileStat(value: shown.posts, title: "Post")
                    ProfileStat(value: shown.places > 0 ? shown.places : Set(posts.map(\.place_id)).count, title: "Luoghi")
                    Button { list = "followers" } label: { ProfileStat(value: shown.followers, title: "Follower") }.buttonStyle(.plain)
                    Button { list = "following" } label: { ProfileStat(value: shown.following, title: "Seguiti") }.buttonStyle(.plain).disabled(!shown.has_account)
                } actions: {
                    if !shown.mine && detail != nil {
                        Button { Task { await toggleFollow() } } label: {
                            Label(shown.is_following ? "Segui già" : shown.follows_you ? "Segui anche tu" : "Segui", systemImage: shown.is_following ? "checkmark" : "person.badge.plus")
                                .foregroundStyle(shown.is_following ? Color.black : .white).frame(maxWidth: .infinity).frame(height: 44)
                                .roamGlassCapsule(interactive: true, tint: shown.is_following ? nil : RoamStyle.red)
                        }.disabled(followBusy)
                        Button { Task { await message() } } label: {
                            Group { if opening { ProgressView() } else { Label("Messaggio", systemImage: "paperplane") } }
                                .foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 44).roamGlassCapsule(interactive: true)
                        }.disabled(opening)
                    }
                }
                if let failure {
                    VStack(alignment: .leading, spacing: 10) { Text(failure).font(.subheadline); Button("Riprova") { Task { await load() } } }.padding(20).roamGlass(24).padding(.horizontal, 16)
                } else if !loaded { ProgressView().frame(maxWidth: .infinity).padding(40) }
                else if posts.isEmpty {
                    RoamEmptyState(icon: "photo.on.rectangle.angled", title: "Nessuna esperienza", message: "Questo viaggiatore non ha ancora condiviso luoghi.").padding(.vertical, 24).roamGlass(26).padding(.horizontal, 16)
                } else {
                    PostsMapCard(posts: posts) { openedPostID = $0.id }
                    ProfileSectionTitle(title: "I suoi luoghi", icon: "square.grid.2x2")
                    PostTileGrid(posts: posts) { openedPostID = $0.id }
                }
            }.padding(.bottom, 12)
        }
        .background { ProfileBackdrop(image: posts.lazy.compactMap { PostImageCache.image($0) }.first) }
        .navigationTitle(shown.name).navigationBarTitleDisplayMode(.inline).toolbarBackground(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(item: $openedPostID) { id in
            if let post = posts.first(where: { $0.id == id }) { SocialPostDetailView(initial: post, place: post.place) }
        }
        .navigationDestination(item: $chat) { ThreadView(conversation: $0) }
        .navigationDestination(item: $list) { kind in ConnectionsView(person: shown, kind: kind) }
    }
    private func load() async {
        do {
            async let profile = store.profile(of: person.key)
            try await store.loadPersonFeed(person)
            detail = try await profile; failure = nil
        } catch { if !Task.isCancelled { failure = "Profilo non disponibile. Riprova." } }
        loaded = true
    }
    private func toggleFollow() async {
        followBusy = true; defer { followBusy = false }
        do { detail = try await store.setFollowing(person.key, !shown.is_following) }
        catch { store.error = error.localizedDescription }
    }
    private func message() async {
        opening = true; defer { opening = false }
        do { chat = try await store.openConversation(with: person.key) } catch { store.error = error.localizedDescription }
    }
}
/// ROAM, the travel assistant: the first, pinned chat in the inbox. Its history is kept on the server.
struct RoamChatView: View {
    let conversation: Conversation
    @EnvironmentObject var store: Store
    @EnvironmentObject var location: LocationService
    @State private var messages: [Message] = []
    @State private var loaded = false
    @State private var input = ""
    @State private var waiting = false
    @State private var confirmClear = false
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoamAvatar(size: 64)
            Text("Partiamo da\nun’idea.").font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1.4)
            Text("Sono ROAM, il tuo assistente di viaggio. Un posto speciale, una pausa o un giro diverso: chiedimi da dove iniziare.").font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Cosa vedere qui?", "Una pausa caffè", "Un giro tra i negozi"], id: \.self) { suggestion in
                        Button { input = suggestion; send() } label: { Text(suggestion).font(.caption.bold()).padding(13).roamGlassCapsule(interactive: true) }.buttonStyle(.plain).foregroundStyle(RoamStyle.red)
                    }
                }
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).roamGlass(30).padding(.top, 8)
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if loaded && messages.isEmpty { welcome }
                        else if !loaded { ProgressView().padding(40) }
                        ForEach(messages) { message in
                            ChatMessageRow(message: message, ask: { question in guard !waiting else { return }; input = question; send() }).id(message.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if waiting { TypingBubble().frame(maxWidth: .infinity, alignment: .leading).id("typing") }
                    }.padding()
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) { _, _ in if let id = messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
                .onChange(of: waiting) { _, now in if now { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } } }
            }
            if !messages.isEmpty {
                Label(location.coordinate == nil ? location.status : "Consigli per te · \(location.city)", systemImage: "location").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5).roamGlassCapsule().padding(.top, 4)
            }
            MessageComposer(text: $input, placeholder: "Chiedi a ROAM…", disabled: waiting) { send() }
        }
        .scrollDismissesKeyboard(.interactively).background { GlassBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    RoamAvatar(size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ROAM").font(.subheadline.bold())
                        Text(waiting ? "Sta scrivendo…" : "Assistente di viaggio").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) { confirmClear = true } label: { Label("Cancella la chat", systemImage: "trash") }
                } label: { Image(systemName: "info.circle") }.disabled(messages.isEmpty)
            }
        }
        .confirmationDialog("Cancellare la chat con ROAM?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Cancella", role: .destructive) { Task { await clear() } }
        } message: { Text("I messaggi vengono eliminati. Ciò che ROAM ha imparato sui tuoi gusti resta in Profilo → Personalizzazione.") }
        .task { await load() }
    }
    private func load() async {
        do {
            let thread: DMThread = try await store.request("/dm/conversations/\(conversation.id)/messages")
            messages = thread.messages.map { Message(id: $0.id, text: $0.body, user: $0.mine, places: $0.places, posts: $0.posts) }
        } catch { if messages.isEmpty { messages = [] } }
        loaded = true
    }
    private func clear() async {
        guard let url = URL(string: store.apiURL + "/dm/roam") else { return }
        _ = try? await URLSession.shared.data(for: store.authorized(url, method: "DELETE"))
        withAnimation { messages = [] }
        await store.loadConversations()
    }
    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !waiting else { return }
        input = ""; withAnimation { messages.append(.init(text: text, user: true)) }; waiting = true
        Task {
            defer { waiting = false }
            do {
                // The assistant always knows where you are; the server adds your preferences and activity.
                var payload: [String: Any] = ["message": text]
                if let c = location.coordinate {
                    payload["latitude"] = c.latitude; payload["longitude"] = c.longitude; payload["area"] = location.city
                    payload["nearby_places"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Array(store.places.prefix(30))))
                } else { location.request() }
                let data = try JSONSerialization.data(withJSONObject: payload)
                let reply: ChatReply = try await store.request("/chat", method: "POST", body: data)
                withAnimation { messages.append(.init(text: reply.reply, user: false, places: reply.places ?? [], posts: reply.posts ?? [])) }
            } catch { messages.append(.init(text: error.localizedDescription, user: false)) }
        }
    }
}
// Profile hero: centred portrait over the blurred last photo, a glass "travel card" of numbers.
struct ProfileBackdrop: View {
    let image: UIImage?
    var body: some View {
        ZStack(alignment: .top) {
            RoamStyle.canvas
            if let image {
                Image(uiImage: image).resizable().scaledToFill().frame(height: 380).frame(maxWidth: .infinity).clipped()
                    .blur(radius: 40).opacity(0.7)
                    .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
            } else {
                LinearGradient(colors: [RoamStyle.red.opacity(0.18), Color(red: 1, green: 0.93, blue: 0.9), .clear], startPoint: .top, endPoint: .bottom).frame(height: 380)
            }
        }.ignoresSafeArea()
    }
}
struct ProfileStat: View {
    let value: Int
    let title: String
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(.black).contentTransition(.numericText())
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase).tracking(0.4)
        }.frame(maxWidth: .infinity).padding(.vertical, 12).contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}
struct ProfileHero<Portrait: View, Stats: View, Actions: View>: View {
    let name: String
    let bio: String
    var notes: [String] = []
    @ViewBuilder let portrait: Portrait
    @ViewBuilder let stats: Stats
    @ViewBuilder let actions: Actions
    var body: some View {
        VStack(spacing: 14) {
            portrait.padding(6).roamGlassCircle().shadow(color: .black.opacity(0.12), radius: 18, y: 8).padding(.top, 12)
            VStack(spacing: 4) {
                Text(name).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.black).multilineTextAlignment(.center)
                if !bio.isEmpty { Text(bio).font(.subheadline).foregroundStyle(.black.opacity(0.75)).multilineTextAlignment(.center) }
                ForEach(notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            }.padding(.horizontal, 24)
            HStack(spacing: 0) { stats }.padding(.horizontal, 6).roamGlass(26).padding(.horizontal, 16)
            HStack(spacing: 10) { actions }.font(.subheadline.weight(.semibold)).buttonStyle(DiscoveryPressStyle()).padding(.horizontal, 16)
        }
    }
}
// Where the posts were taken: one pin per place, tap to open its latest post.
struct PostsMapCard: View {
    let posts: [SocialPost]
    let onOpen: (SocialPost) -> Void
    private var places: [(Place, SocialPost)] {
        var seen = Set<String>()
        return posts.compactMap { seen.insert($0.place_id).inserted ? ($0.place, $0) : nil }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("La mappa dei viaggi", systemImage: "map").font(.subheadline.bold()).foregroundStyle(.black)
                Spacer()
                Text(places.count == 1 ? "1 luogo" : "\(places.count) luoghi").font(.caption.weight(.semibold)).foregroundStyle(RoamStyle.red)
            }
            Map(initialPosition: .automatic) {
                ForEach(places, id: \.0.id) { place, post in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        Button { onOpen(post) } label: { RoamMapPin(place: place).scaleEffect(0.8) }.buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }.padding(14).roamGlass(26).padding(.horizontal, 16)
    }
}
struct ProfileSectionTitle: View {
    let title: String
    let icon: String
    var body: some View {
        Label(title, systemImage: icon).font(.headline).foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).accessibilityAddTraits(.isHeader)
    }
}

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @State private var composing = false
    @State private var openedPostID: String?
    private var me: Person { var p = Person(key: "u:\(store.user?.id ?? 0)", name: store.profile.name, photo: store.profile.photo); p.mine = true; return p }
    private var placesCount: Int { Set(store.myPosts.map(\.place_id)).count }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ProfileHero(name: store.profile.name, bio: store.profile.bio, notes: store.accountError.map { [$0] } ?? []) {
                        Avatar(photo: store.profile.photo, size: 104)
                    } stats: {
                        ProfileStat(value: store.stats.posts, title: "Post")
                        ProfileStat(value: placesCount, title: "Luoghi")
                        NavigationLink { ConnectionsView(person: me, kind: "followers") } label: { ProfileStat(value: store.stats.followers, title: "Follower") }.buttonStyle(.plain)
                        NavigationLink { ConnectionsView(person: me, kind: "following") } label: { ProfileStat(value: store.stats.following, title: "Seguiti") }.buttonStyle(.plain)
                    } actions: {
                        NavigationLink { EditProfileView(profile: store.profile) } label: {
                            Label("Modifica", systemImage: "pencil").foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 44).roamGlassCapsule(interactive: true)
                        }
                        Button { composing = true } label: {
                            Label("Nuovo post", systemImage: "plus").foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 44).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                        }
                    }
                    if store.myPosts.isEmpty {
                        if let issue = store.myPostsError {
                            VStack(spacing: 10) { Text(issue).font(.subheadline); Button("Riprova") { Task { await store.loadMyPosts() } } }.padding(24).roamGlass(24).padding(.horizontal, 16)
                        } else if !store.myPostsLoaded { ProgressView().padding(40) }
                        else {
                            RoamEmptyState(icon: "camera", title: "Condividi il tuo primo luogo", message: "Le foto che pubblichi appariranno qui e sulla tua mappa dei viaggi.", action: "Pubblica un post") { composing = true }
                                .padding(.vertical, 24).roamGlass(26).padding(.horizontal, 16)
                        }
                    } else {
                        PostsMapCard(posts: store.myPosts) { openedPostID = $0.id }
                        ProfileSectionTitle(title: "I tuoi luoghi", icon: "square.grid.2x2")
                        PostTileGrid(posts: store.myPosts) { openedPostID = $0.id }
                    }
                }.padding(.bottom, 12)
            }
            .background { ProfileBackdrop(image: store.myPosts.lazy.compactMap { PostImageCache.image($0) }.first) }
            .navigationTitle("Profilo").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink { ProfileSettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel("Impostazioni")
                }
            }
            .navigationDestination(item: $openedPostID) { id in
                if let post = store.myPosts.first(where: { $0.id == id }) { SocialPostDetailView(initial: post, place: post.place) }
            }
            .task { await store.loadMyPosts() }
            .refreshable { await store.loadMyPosts(); if let stats: Stats = try? await store.request("/stats") { store.stats = stats } }
            .sheet(isPresented: $composing) { SocialComposer(places: store.knownPlaces) { _ in } }
        }
    }
}

// Profile grid tile: same language as the feed preview, at half width.
struct PostTile: View {
    let post: SocialPost
    var body: some View {
        Color.clear.aspectRatio(4 / 5, contentMode: .fit)
            .overlay {
                if let image = PostImageCache.image(post) { Image(uiImage: image).resizable().scaledToFill() }
                else { PlaceVisual(place: post.place, height: 240) }
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.place.name).font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(.black).lineLimit(1)
                    HStack(spacing: 6) {
                        RatingStars(rating: post.rating)
                        Spacer(minLength: 0)
                        if post.comments > 0 { Label("\(post.comments)", systemImage: "bubble.right").font(.caption2).foregroundStyle(.secondary) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 8).roamGlass(16).padding(7)
            }
            .overlay(alignment: .topTrailing) {
                if post.saved { Image(systemName: "bookmark.fill").font(.caption.bold()).foregroundStyle(RoamStyle.red).frame(width: 30, height: 30).background(.regularMaterial, in: Circle()).overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1)).padding(7) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Post su \(post.place.name), \(post.rating) stelle. Apri i dettagli")
    }
}
struct PostTileGrid: View {
    let posts: [SocialPost]
    let onOpen: (SocialPost) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(posts) { post in
                Button { onOpen(post) } label: { PostTile(post: post) }.buttonStyle(DiscoveryPressStyle())
            }
        }.padding(.horizontal, 16).padding(.bottom, 24)
    }
}
struct PostThumbnail: View {
    let post: SocialPost
    var body: some View {
        Color.clear.aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = PostImageCache.image(post) { Image(uiImage: image).resizable().scaledToFill() }
                else { ZStack { Color.white; PlaceGlyph(category: post.place.category).frame(width: 28, height: 28).foregroundStyle(RoamStyle.red) }.overlay(Rectangle().strokeBorder(RoamStyle.red, lineWidth: 0.5)) }
            }
            .clipped().contentShape(Rectangle())
            .accessibilityLabel("Post su \(post.place.name)")
    }
}

// Settings as glass cards, one per topic.
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    var footer: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title.uppercased(), systemImage: icon).font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundStyle(RoamStyle.red).padding(.horizontal, 8)
            VStack(alignment: .leading, spacing: 0) { content }.roamGlass(24)
            if let footer { Text(footer).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8) }
        }
    }
}
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = RoamStyle.red
    @ViewBuilder var accessory: Accessory
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint).frame(width: 34, height: 34).roamGlassCircle()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.black)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 8)
            accessory
        }.padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
    }
}
extension SettingsRow where Accessory == EmptyView {
    init(icon: String, title: String, subtitle: String? = nil, tint: Color = RoamStyle.red) {
        self.init(icon: icon, title: title, subtitle: subtitle, tint: tint) { EmptyView() }
    }
}
struct SettingsDivider: View {
    var body: some View { Rectangle().fill(.black.opacity(0.06)).frame(height: 1).padding(.leading, 60) }
}

struct ProfileSettingsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var location: LocationService
    @State private var confirmSignOut = false
    private var chevron: some View { Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TravelDashboard(profile: store.profile, stats: store.stats)
                SettingsCard(title: "Account", icon: "person.crop.circle") {
                    if let user = store.user {
                        SettingsRow(icon: "envelope", title: "Accesso", subtitle: user.email ?? user.name)
                        SettingsDivider()
                        SettingsRow(icon: "key", title: "Metodi", subtitle: user.providers.map { ["password": "Email", "apple": "Apple", "google": "Google"][$0] ?? $0 }.joined(separator: ", "))
                        SettingsDivider()
                    }
                    NavigationLink { EditProfileView(profile: store.profile) } label: {
                        SettingsRow(icon: "pencil", title: "Modifica profilo", subtitle: "Nome, bio e foto") { chevron }
                    }.buttonStyle(.plain)
                }
                SettingsCard(title: "Assistente personale", icon: "sparkles") {
                    NavigationLink { PersonalizationView() } label: {
                        SettingsRow(icon: "sparkles", title: "Cosa sa Roam di te", subtitle: "Preferenze e memoria dell’assistente") { chevron }
                    }.buttonStyle(.plain)
                }
                SettingsCard(title: "Privacy e posizione", icon: "hand.raised",
                             footer: "La posizione si aggiorna quando usi l’app. I luoghi arrivano da OpenStreetMap tramite il server e da Mappe Apple, il meteo da Open-Meteo. La chat invia la posizione anche all’assistente configurato.") {
                    SettingsRow(icon: "map", title: "Luoghi durante zoom e spostamenti", subtitle: "Invia ad Apple l’area visibile della mappa; può includere luoghi oltre 5 km.") {
                        Toggle("", isOn: $store.viewportSearchEnabled).labelsHidden()
                    }
                    SettingsDivider()
                    SettingsRow(icon: "apple.logo", title: "Ricerca con Mappe Apple", subtitle: "Invia la posizione e il testo cercato ad Apple. Serve anche per cercare le città.") {
                        Toggle("", isOn: $store.appleSearchEnabled).labelsHidden()
                            .onChange(of: store.appleSearchEnabled) { _, _ in Task { await store.loadPlaces(location.coordinate) } }
                    }
                    SettingsDivider()
                    Button { location.request() } label: {
                        SettingsRow(icon: "location", title: "Aggiorna la mia posizione", subtitle: location.coordinate == nil ? location.status : location.city) { chevron }
                    }.buttonStyle(.plain)
                    if location.permissionDenied {
                        SettingsDivider()
                        Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: {
                            SettingsRow(icon: "gearshape", title: "Apri Impostazioni posizione", subtitle: "La posizione è disattivata per Roam") { Image(systemName: "arrow.up.right").font(.caption.bold()).foregroundStyle(.secondary) }
                        }.buttonStyle(.plain)
                    }
                }
                .tint(RoamStyle.red)
                SettingsCard(title: "Connessione al backend", icon: "server.rack", footer: "Foto, viaggi e commenti sono conservati sul server configurato.") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let issue = store.accountError { Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(RoamStyle.red) }
                        TextField("URL API", text: $store.apiURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.subheadline.monospaced()).padding(.horizontal, 14).padding(.vertical, 12).roamGlassCapsule()
                        Button { Task { await store.load(location.coordinate); await store.loadMyPosts() } } label: {
                            Label("Riconnetti e aggiorna", systemImage: "arrow.clockwise").font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).frame(height: 44).foregroundStyle(.white).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                        }.buttonStyle(DiscoveryPressStyle())
                    }.padding(14)
                }
                Button { confirmSignOut = true } label: {
                    Label("Esci", systemImage: "rectangle.portrait.and.arrow.right").font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).frame(height: 48).foregroundStyle(RoamStyle.red).roamGlassCapsule(interactive: true)
                }.buttonStyle(DiscoveryPressStyle()).padding(.top, 4)
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 32)
        }
        .background { GlassBackdrop() }
        .navigationTitle("Impostazioni").roamHeader()
        .confirmationDialog("Uscire da Roam?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Esci", role: .destructive) { store.signOut() }
            Button("Annulla", role: .cancel) {}
        } message: { Text("Potrai accedere di nuovo con le tue credenziali.") }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Profile
    @State private var selection: PhotosPickerItem?
    @State private var saving = false
    @State private var loadingPhoto = false
    @State private var failure: String?
    init(profile: Profile) { _draft = State(initialValue: profile) }
    private var valid: Bool { !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.name.count <= 80 && draft.bio.count <= 500 }
    var body: some View {
        Form { Group {
            Section {
                VStack(spacing: 16) {
                    Avatar(photo: draft.photo, size: 96).padding(5).roamGlassCircle()
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label(loadingPhoto ? "Caricamento…" : "Scegli foto", systemImage: "camera")
                    }.disabled(saving || loadingPhoto)
                    if draft.photo != nil {
                        Button("Rimuovi foto", role: .destructive) { selection = nil; draft.photo = nil }.disabled(saving || loadingPhoto)
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            Section {
                TextField("Come ti chiami?", text: $draft.name).textContentType(.name).disabled(saving)
            } header: { Text("Nome") } footer: { Text("Fino a 80 caratteri.") }
            Section {
                TextField("Racconta che esploratore sei…", text: $draft.bio, axis: .vertical).lineLimit(4...8).disabled(saving)
            } header: { Text("Bio") } footer: { Text("\(draft.bio.count)/500 caratteri").foregroundStyle(draft.bio.count > 500 ? Color.red : Color.secondary) }
            if let failure { Section { Text(failure).font(.subheadline).foregroundStyle(.red) } }
        }.listRowBackground(GlassRowBackground())
}
        .roamGlassForm().tint(RoamStyle.red)
        .navigationTitle("Modifica profilo").navigationBarBackButtonHidden(true).roamHeader()
        .interactiveDismissDisabled(saving || loadingPhoto)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) {
                Button { save() } label: { if saving { ProgressView() } else { Text("Salva").bold() } }
                    .disabled(!valid || saving || loadingPhoto)
            }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            loadingPhoto = true; failure = nil
            Task {
                defer { loadingPhoto = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                        failure = "Non riesco a leggere questa immagine. Scegli un’altra foto."; return
                    }
                    let ratio = min(1, 600 / max(image.size.width, image.size.height))
                    let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                    guard let jpeg = resized.jpegData(compressionQuality: 0.7) else { return }
                    draft.photo = jpeg.base64EncodedString()
                } catch { failure = "Caricamento foto non riuscito. Riprova." }
            }
        }
    }
    private func save() {
        saving = true; failure = nil
        var value = draft
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            defer { saving = false }
            do {
                let profile: Profile = try await store.request("/profile", method: "PUT", body: JSONEncoder().encode(value))
                store.profile = profile
                dismiss()
            } catch { failure = "Non riesco a salvare il profilo. Controlla la connessione e riprova: le tue modifiche sono ancora qui." }
        }
    }
}

// MARK: - Personalization

private struct ChoiceGrid: View {
    let options: [String]
    let selected: Set<String>
    let toggle: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = selected.contains(option)
                Button { toggle(option) } label: {
                    Text(option).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(on ? .white : .primary)
                        .roamGlassCapsule(interactive: true, tint: on ? RoamStyle.red : nil)
                }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

struct PreferencesForm: View {
    @Binding var value: TravelPreferences
    static let interests = ["Attrazione", "Caffè", "Ristorante", "Negozio", "Parco", "Arte", "Storia", "Vita notturna", "Fotografia", "Natura"]
    private func single(_ title: String, _ options: [String], _ key: WritableKeyPath<TravelPreferences, String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ChoiceGrid(options: options, selected: [value[keyPath: key]]) { value[keyPath: key] = value[keyPath: key] == $0 ? "" : $0 }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cosa ti piace scoprire?").font(.headline)
                ChoiceGrid(options: Self.interests, selected: Set(value.interests)) { item in
                    if let i = value.interests.firstIndex(of: item) { value.interests.remove(at: i) } else { value.interests.append(item) }
                }
            }
            single("Che viaggiatore sei?", ["cultura", "relax", "avventura", "gastronomia", "shopping"], \.travel_style)
            single("Ritmo", ["lento", "equilibrato", "intenso"], \.pace)
            single("Budget", ["economico", "medio", "alto"], \.budget)
            single("Con chi viaggi?", ["da solo", "in coppia", "con amici", "in famiglia"], \.companions)
            VStack(alignment: .leading, spacing: 10) {
                Text("Esigenze alimentari").font(.headline)
                TextField("Es. vegetariano, senza glutine", text: $value.dietary).padding(14).roamGlass(18)
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var value = TravelPreferences()
    @State private var saving = false
    @State private var failure: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(RoamStyle.red)
                        Text("Il tuo assistente di viaggio").font(.largeTitle.bold())
                        Text("Qualche risposta e Roam ti consiglia da subito luoghi su misura. Poi impara da ciò che salvi, cerchi e commenti.").foregroundStyle(.secondary)
                    }
                    PreferencesForm(value: $value)
                    if let failure { Text(failure).font(.caption).foregroundStyle(RoamStyle.red) }
                    Button { Task { await save(value) } } label: {
                        Group { if saving { ProgressView().tint(.white) } else { Text("Inizia a esplorare") } }
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                            .roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                    }.disabled(saving)
                }.padding(24)
            }
            .background { GlassBackdrop() }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Salta") { Task { await save(TravelPreferences()) } }.disabled(saving) } }
        }.interactiveDismissDisabled()
    }
    private func save(_ preferences: TravelPreferences) async {
        saving = true; defer { saving = false }
        do { try await store.savePreferences(preferences) }
        catch { failure = "Non riesco a salvare. Controlla la connessione al backend." }
    }
}

struct PersonalizationView: View {
    @EnvironmentObject var store: Store
    @State private var value = TravelPreferences()
    @State private var memory: AIMemory?
    @State private var message: String?
    @State private var confirmReset = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Cosa ha imparato", systemImage: "sparkles").font(.headline)
                    Text(memory.map { $0.summary.isEmpty ? "Ancora niente: salva post, apri luoghi e chatta con l’assistente." : $0.summary } ?? "Caricamento…")
                        .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).roamGlass(18)
                    Text("Solo questa sintesi breve viene inviata all’assistente, mai la cronologia completa.").font(.caption).foregroundStyle(.secondary)
                    Button("Dimentica ciò che ha imparato", role: .destructive) { confirmReset = true }.font(.subheadline)
                }
                PreferencesForm(value: $value)
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                Button {
                    Task {
                        do { try await store.savePreferences(value); message = "Preferenze salvate."; await reload() }
                        catch { message = "Non riesco a salvare. Controlla la connessione al backend." }
                    }
                } label: {
                    Text("Salva preferenze").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                }
            }.padding(20)
        }
        .background { GlassBackdrop() }.navigationTitle("Personalizzazione").navigationBarTitleDisplayMode(.inline).roamHeader()
        .task { if let p = store.preferences { value = p }; await reload() }
        .confirmationDialog("Roam dimenticherà like, ricerche e luoghi visti. Le tue preferenze restano.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Dimentica", role: .destructive) {
                Task {
                    guard let url = URL(string: store.apiURL + "/me/memory") else { return }
                    _ = try? await URLSession.shared.data(for: store.authorized(url, method: "DELETE"))
                    await reload()
                }
            }
        }
    }
    private func reload() async {
        do { memory = try await store.request("/me/memory") } catch { message = "Memoria non disponibile. Controlla la connessione al backend." }
    }
}

// MARK: - Sign in

/// Google Sign-In without the SDK: OAuth 2.0 authorization code + PKCE for an iOS client.
@MainActor final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    /// Returns a Google ID token, verified again by the backend.
    func idToken(clientID: String) async throws -> String {
        let scheme = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        let redirect = scheme + ":/oauth2redirect"
        let verifier = Self.base64URL(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = UUID().uuidString
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"), .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge), .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state), .init(name: "prompt", value: "select_account"),
        ]
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: scheme) { url, error in
                if let url { continuation.resume(returning: url) } else { continuation.resume(throwing: error ?? URLError(.cancelled)) }
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state, let code = items.first(where: { $0.name == "code" })?.value else { throw URLError(.userAuthenticationRequired) }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [.init(name: "code", value: code), .init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: redirect),
                           .init(name: "grant_type", value: "authorization_code"), .init(name: "code_verifier", value: verifier)]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let token = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["id_token"] as? String else { throw URLError(.userAuthenticationRequired) }
        return token
    }
}

struct LoginView: View {
    @EnvironmentObject var store: Store
    @State private var config: AuthConfig?
    @State private var registering = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var failure: String?
    @State private var showServer = false
    @State private var google = GoogleSignIn()
    private var canSubmit: Bool { email.contains("@") && password.count >= (registering ? 8 : 1) && (!registering || !name.trimmingCharacters(in: .whitespaces).isEmpty) }
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    RoamMark().stroke(RoamStyle.red, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)).frame(width: 64, height: 64)
                    Text(registering ? "Crea il tuo account" : "Bentornato su Roam").font(.title.bold())
                    Text("Il tuo assistente di viaggio impara da ciò che ami. Accedi per ritrovare viaggi, post e consigli.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.top, 40)

                if config?.apple == true {
                    SignInWithAppleButton(registering ? .signUp : .signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in Task { await apple(result) } }
                    .signInWithAppleButtonStyle(.black).frame(height: 50).clipShape(Capsule())
                }
                if let clientID = config?.google_client_id {
                    Button { Task { await signInWithGoogle(clientID) } } label: {
                        HStack(spacing: 10) {
                            Text("G").font(.title3.bold()).foregroundStyle(.blue)
                            Text("Continua con Google").font(.headline)
                        }.foregroundStyle(.primary).frame(maxWidth: .infinity).frame(height: 50)
                        .roamGlassCapsule(interactive: true)
                    }.buttonStyle(.plain)
                }
                if config?.apple == true || config?.google_client_id != nil {
                    HStack { Rectangle().frame(height: 1); Text("oppure").font(.caption); Rectangle().frame(height: 1) }.foregroundStyle(.secondary.opacity(0.6))
                }

                VStack(spacing: 12) {
                    if registering {
                        TextField("Nome", text: $name).textContentType(.name).padding(16).roamGlass(18)
                    }
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(16).roamGlass(18)
                    SecureField(registering ? "Password (almeno 8 caratteri)" : "Password", text: $password).textContentType(registering ? .newPassword : .password)
                        .padding(16).roamGlass(18)
                }
                if let failure { Text(failure).font(.footnote).foregroundStyle(RoamStyle.red).multilineTextAlignment(.center) }
                Button { Task { await submit() } } label: {
                    Group { if busy { ProgressView().tint(.white) } else { Text(registering ? "Registrati" : "Accedi") } }
                        .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50)
                        .roamGlassCapsule(interactive: true, tint: canSubmit ? RoamStyle.red : RoamStyle.red.opacity(0.4))
                }.disabled(!canSubmit || busy)
                Button(registering ? "Hai già un account? Accedi" : "Nuovo su Roam? Crea un account") { registering.toggle(); failure = nil }.font(.subheadline)

                DisclosureGroup("Server", isExpanded: $showServer) {
                    TextField("URL API", text: $store.apiURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).roamGlass(14)
                    Button("Riprova connessione") { Task { await loadConfig() } }.font(.footnote)
                }.font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
            }.padding(24)
        }
        .background { GlassBackdrop() }
        .task { await loadConfig() }
    }
    private func loadConfig() async {
        do { config = try await store.request("/auth/config"); failure = nil }
        catch { failure = "Server non raggiungibile. Controlla Tailscale e il backend." }
    }
    private func finish(_ path: String, _ body: [String: String]) async {
        busy = true; defer { busy = false }
        do {
            let session: AuthSessionResponse = try await store.request(path, method: "POST", body: JSONSerialization.data(withJSONObject: body))
            failure = nil; store.signedIn(session)
        } catch { failure = error.localizedDescription }
    }
    private func submit() async {
        let base = ["email": email.trimmingCharacters(in: .whitespaces), "password": password]
        await finish(registering ? "/auth/register" : "/auth/login", registering ? base.merging(["name": name.trimmingCharacters(in: .whitespaces)]) { $1 } : base)
    }
    private func apple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else { failure = "Accesso con Apple non riuscito."; return }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            await finish("/auth/apple", ["identity_token": token, "name": fullName])
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { failure = "Accesso con Apple non disponibile su questa installazione." }
        }
    }
    private func signInWithGoogle(_ clientID: String) async {
        do { await finish("/auth/google", ["id_token": try await google.idToken(clientID: clientID)]) }
        catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin { failure = "Accesso con Google non riuscito. Riprova." }
        }
    }
}

// MARK: - Chat recommendations

struct ChatMessageRow: View {
    let message: Message
    var ask: (String) -> Void = { _ in }
    private var text: AttributedString {
        (try? AttributedString(markdown: message.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(message.text)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if message.user { Spacer(minLength: 40) }
                Text(text).textSelection(.enabled).foregroundStyle(message.user ? Color.white : Color.black).padding(.horizontal, 16).padding(.vertical, 12)
                    .roamGlass(22, tint: message.user ? RoamStyle.red : nil)
                if !message.user { Spacer(minLength: 40) }
            }
            if !message.places.isEmpty { ChatPlacesPanel(places: message.places, posts: message.posts, ask: ask) }
        }
    }
}

private func distanceText(_ km: Double) -> String { km < 1 ? "\(Int((km * 1000).rounded())) m" : String(format: "%.1f km", km) }

/// A dedicated window inside the chat: pick a place on the map or in the carousel,
/// then read, like posts, ask the assistant or get directions without leaving the conversation.
struct ChatPlacesPanel: View {
    let places: [Place]
    let ask: (String) -> Void
    @EnvironmentObject var store: Store
    @State private var posts: [SocialPost]
    @State private var selected: String?
    @State private var mapSelection: String?
    @State private var camera: MapCameraPosition
    @State private var fullPlace: Place?
    @State private var expandedPost: String?
    @State private var comments: [String: [SocialComment]] = [:]
    @State private var commentsFailed = Set<String>()
    @State private var draft = ""
    @State private var sendingComment = false
    @State private var person: Person?
    @State private var openingAuthor: String?
    init(places: [Place], posts: [SocialPost], ask: @escaping (String) -> Void) {
        self.places = places; self.ask = ask
        _posts = State(initialValue: posts)
        _selected = State(initialValue: places.first?.id)
        _camera = State(initialValue: .region(Self.region(places)))
    }
    private static func region(_ places: [Place]) -> MKCoordinateRegion {
        let lats = places.map(\.latitude), lons = places.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        return MKCoordinateRegion(center: center, span: .init(latitudeDelta: max(0.008, (lats.max()! - lats.min()!) * 1.7), longitudeDelta: max(0.008, (lons.max()! - lons.min()!) * 1.7)))
    }
    private var place: Place? { places.first { $0.id == selected } }
    private func select(_ id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selected = id; expandedPost = nil
            if let p = places.first(where: { $0.id == id }) {
                camera = .region(MKCoordinateRegion(center: p.coordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Per te qui", systemImage: "sparkles").font(.subheadline.bold()).foregroundStyle(RoamStyle.red)
                Spacer()
                Text(places.count == 1 ? "1 luogo" : "\(places.count) luoghi").font(.caption).foregroundStyle(.secondary)
            }
            Map(position: $camera, selection: $mapSelection) {
                UserAnnotation()
                ForEach(places) { p in
                    Marker(p.name, systemImage: p.symbol, coordinate: p.coordinate)
                        .tint(p.id == selected ? RoamStyle.red : Color.gray).tag(p.id)
                }
            }
            .mapControlVisibility(.hidden)
            .frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                if places.count > 1 {
                    Button { withAnimation { camera = .region(Self.region(places)) } } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption.bold()).padding(8).roamGlassCircle()
                    }.buttonStyle(.plain).padding(8).accessibilityLabel("Mostra tutti i luoghi")
                }
            }
            .onChange(of: mapSelection) { _, id in if let id { select(id); mapSelection = nil } }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(places) { p in
                        Button { select(p.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                PlaceVisual(place: p, height: 84).clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(p.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text("\(p.category) · \(distanceText(p.distance))").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(8).frame(width: 168, alignment: .leading)
                            .roamGlass(16)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(p.id == selected ? RoamStyle.red : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityAddTraits(p.id == selected ? .isSelected : [])
                    }
                }
            }

            if let place { detail(place).transition(.opacity.combined(with: .move(edge: .top))) }
        }
        .padding(14).roamGlass(24)
        .sheet(item: $fullPlace) { PlaceSheet(place: $0) }
        .sheet(item: $person) { person in
            NavigationStack {
                PersonView(person: person)
                    .navigationDestination(for: Person.self) { PersonView(person: $0) }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { self.person = nil }.foregroundStyle(RoamStyle.red) } }
            }
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible).presentationCornerRadius(32)
        }
    }

    @ViewBuilder private func detail(_ place: Place) -> some View {
        let activity = store.activity[place.id]
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name).font(.headline)
                HStack(spacing: 6) {
                    Text("\(place.category) · \(distanceText(place.distance))")
                    if let rating = activity?.rating { Text("· ★ \(String(format: "%.1f", rating))") }
                    if let count = activity?.comments, count > 0 { Text("· \(count) recensioni") }
                }.font(.caption).foregroundStyle(.secondary)
                if !place.description.isEmpty { Text(place.description).font(.footnote).foregroundStyle(.secondary).lineLimit(3) }
            }
            HStack(spacing: 8) {
                action("Indicazioni", "arrow.triangle.turn.up.right.diamond.fill") {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)); item.name = place.name
                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                }
                action("Chiedi", "bubble.left.fill") { ask("Parlami di \(place.name): perché fa per me e cosa fare lì?") }
                action("Scheda", "info.circle.fill") { fullPlace = place }
            }
            let placePosts = posts.filter { $0.place_id == place.id }
            if placePosts.isEmpty {
                Text("Ancora nessun post di viaggiatori qui.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Dai viaggiatori").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(placePosts) { post in postRow(post) }
            }
        }
        .task(id: place.id) { await store.refreshActivity(place) }
    }

    private func action(_ title: String, _ icon: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).lineLimit(1)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .roamGlassCapsule(interactive: true).foregroundStyle(RoamStyle.red)
        }.buttonStyle(.plain)
    }

    private func postRow(_ post: SocialPost) -> some View {
        let expanded = expandedPost == post.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                PostThumbnail(post: post).frame(width: expanded ? 120 : 64, height: expanded ? 120 : 64).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button { Task { await openAuthor(post) } } label: {
                            HStack(spacing: 4) {
                                Text(post.author).font(.caption.bold()).lineLimit(1)
                                if openingAuthor == post.author { ProgressView().controlSize(.mini) } else { Image(systemName: "chevron.right").font(.caption2) }
                            }
                        }.buttonStyle(.plain).foregroundStyle(.primary).accessibilityLabel("Apri il profilo di \(post.author)")
                        Text(String(repeating: "★", count: post.rating)).font(.caption2).foregroundStyle(RoamStyle.red)
                        Spacer()
                        Button { Task { await like(post) } } label: {
                            Image(systemName: post.saved ? "heart.fill" : "heart").foregroundStyle(post.saved ? RoamStyle.red : .secondary)
                        }.buttonStyle(.plain).accessibilityLabel(post.saved ? "Rimuovi dai salvati" : "Salva post")
                    }
                    Text(post.body).font(.footnote).lineLimit(expanded ? nil : 2)
                    Label(post.comments == 0 ? "Commenta" : "\(post.comments) commenti", systemImage: "bubble.right").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { toggle(post) }
            if expanded { commentsSection(post) }
        }
    }

    private func toggle(_ post: SocialPost) {
        withAnimation(.spring(response: 0.3)) { expandedPost = expandedPost == post.id ? nil : post.id; draft = "" }
        if expandedPost == post.id, comments[post.id] == nil { Task { await loadComments(post) } }
    }

    @ViewBuilder private func commentsSection(_ post: SocialPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let list = comments[post.id] {
                if list.isEmpty { Text("Nessun commento: scrivi il primo.").font(.caption).foregroundStyle(.secondary) }
                ForEach(list) { comment in
                    (Text(comment.author).bold() + Text("  " + comment.body)).font(.caption)
                }
            } else if commentsFailed.contains(post.id) {
                Button("Commenti non disponibili. Riprova") { Task { await loadComments(post) } }.font(.caption)
            } else { ProgressView().controlSize(.small) }
            HStack(spacing: 8) {
                TextField("Aggiungi un commento…", text: $draft, axis: .vertical).font(.footnote).lineLimit(1...3)
                    .padding(.horizontal, 12).padding(.vertical, 8).roamGlassCapsule()
                Button { Task { await sendComment(post) } } label: {
                    if sendingComment { ProgressView().controlSize(.small) } else { Image(systemName: "paperplane.fill") }
                }
                .disabled(sendingComment || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .foregroundStyle(RoamStyle.red).accessibilityLabel("Pubblica commento")
            }
        }
        .padding(.leading, 4)
    }

    private func loadComments(_ post: SocialPost) async {
        commentsFailed.remove(post.id)
        do { comments[post.id] = try await store.request("/feed/posts/\(post.id)/comments") }
        catch { commentsFailed.insert(post.id) }
    }

    private func sendComment(_ post: SocialPost) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendingComment = true; defer { sendingComment = false }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["body": text])
            let comment: SocialComment = try await store.request("/feed/posts/\(post.id)/comments", method: "POST", body: body)
            comments[post.id, default: []].append(comment); draft = ""
            if let index = posts.firstIndex(where: { $0.id == post.id }) { posts[index].comments += 1 }
            store.updatePost(post.id) { $0.comments += 1 }
        } catch { store.error = "Commento non pubblicato. Riprova." }
    }

    private func openAuthor(_ post: SocialPost) async {
        guard !post.mine, let key = post.author_key else { return }
        person = Person(key: key, name: post.author, photo: post.author_profile?.photo)
    }

    private func like(_ post: SocialPost) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let target = !posts[index].saved
        posts[index].saved = target  // optimistic: the heart reacts at once
        do {
            let body = try JSONSerialization.data(withJSONObject: ["saved": target])
            let result: SavedResponse = try await store.request("/feed/posts/\(post.id)/saved", method: "PUT", body: body)
            posts[index].saved = result.saved
            store.updatePost(post.id) { $0.saved = result.saved }
        } catch { posts[index].saved = !target; store.error = "Salvataggio non riuscito. Riprova." }
    }
}
