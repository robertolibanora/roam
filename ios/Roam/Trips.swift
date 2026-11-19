import SwiftUI
import MapKit

// Trips in the feed: a whole holiday told through a collection of posts.
// Same visual language as the posts: photos edge to edge, glass captions, red accents.

func tripPostDate(_ value: String) -> Date? {
    let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return parser.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}
private func tripDay(_ value: String) -> Date? {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: value)
}

// Top of the feed: Post or Trip. Text tabs with a red underline, above the scope capsules.
struct FeedKindSwitch: View {
    @Binding var selection: String
    @Namespace private var underline
    private let options: [(String, String)] = [("Post", "square.grid.2x2"), ("Trip", "suitcase.rolling")]
    var body: some View {
        HStack(spacing: 28) {
            ForEach(options, id: \.0) { option, icon in
                let selected = selection == option
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = option } } label: {
                    Label(option, systemImage: icon)
                        .font(.system(.headline, design: .rounded, weight: selected ? .bold : .medium))
                        .foregroundStyle(selected ? Color.black : Color.black.opacity(0.4))
                        .padding(.bottom, 9)
                        .overlay(alignment: .bottom) {
                            if selected { Capsule().fill(RoamStyle.red).frame(height: 3).matchedGeometryEffect(id: "underline", in: underline) }
                        }
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22).padding(.top, 2).padding(.bottom, 12)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// Cover of a trip: one large photo and up to two smaller ones beside it.
struct TripMosaic: View {
    let posts: [SocialPost]
    var height: CGFloat = 320
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                tile(posts.first).frame(width: posts.count > 1 ? geo.size.width * 0.64 : geo.size.width)
                if posts.count > 1 {
                    VStack(spacing: 3) { ForEach(posts.dropFirst().prefix(2)) { tile($0) } }
                }
            }
        }.frame(height: height).frame(maxWidth: .infinity)
    }
    private func tile(_ post: SocialPost?) -> some View {
        Color.white.frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if let post {
                    if let image = PostImageCache.image(post) { Image(uiImage: image).resizable().scaledToFill() }
                    else { PlaceVisual(place: post.place, height: height) }
                }
            }.clipped()
    }
}

struct TripAuthorCapsule: View {
    let story: TripStory
    var showDate = true
    @EnvironmentObject private var store: Store
    var body: some View {
        HStack(spacing: 7) {
            Avatar(photo: story.mine ? store.profile.photo : story.author_photo, size: 24)
            Text(story.mine ? store.profile.name : story.author).font(.caption.bold()).foregroundStyle(.black).lineLimit(1)
            if showDate { Text(postDateLabel(story.created_at)).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
        }.padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4).roamGlassCapsule()
    }
}

// Feed card for a trip, the sibling of SocialPostPreview.
struct TripStoryCard: View {
    let story: TripStory
    let onOpen: () -> Void
    private var place: String { story.destination.isEmpty ? (story.posts.first?.place.name ?? "") : story.destination }
    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottom) {
                TripMosaic(posts: story.posts, height: 340)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(story.title).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(.black).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(story.days == 1 ? "1 giorno" : "\(story.days) giorni").font(.caption.weight(.bold)).foregroundStyle(RoamStyle.red)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                        Text(place).lineLimit(1)
                        if !story.dateRange.isEmpty { Text("·"); Text(story.dateRange).lineLimit(1) }
                    }.font(.subheadline).foregroundStyle(.black.opacity(0.75))
                    HStack(spacing: 12) {
                        Label(story.post_count == 1 ? "1 post" : "\(story.post_count) post", systemImage: "photo.stack")
                        Label(story.place_count == 1 ? "1 luogo" : "\(story.place_count) luoghi", systemImage: "map")
                        Spacer(minLength: 0)
                        HStack(spacing: 3) { Text("Apri il viaggio"); Image(systemName: "chevron.right") }.foregroundStyle(RoamStyle.red).fontWeight(.semibold)
                    }.font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                }.padding(14).roamGlass(22).padding(10)
            }
            .overlay(alignment: .topLeading) { TripAuthorCapsule(story: story).padding(12) }
            .overlay(alignment: .topTrailing) {
                Label("Trip", systemImage: "suitcase.rolling.fill").font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6).roamGlassCapsule(tint: RoamStyle.red).padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        }
        .buttonStyle(DiscoveryPressStyle())
        .accessibilityLabel("Viaggio \(story.title) di \(story.author), \(story.post_count) post. Apri")
    }
}

// The Trip half of the feed: scopes, composer entry and the list of trips.
struct TripFeedContent: View {
    @EnvironmentObject private var store: Store
    @AppStorage("tripFeedScope") private var scope = "Tutti"
    let onCompose: () -> Void
    let onOpen: (TripStory) -> Void
    static func apiScope(_ scope: String) -> String { scope == "Seguiti" ? "following" : scope == "I miei" ? "mine" : "all" }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoamTabs(options: ["Seguiti", "Tutti", "I miei"], selection: $scope).padding(.horizontal, 16).padding(.bottom, 12)
            Button(action: onCompose) {
                HStack(spacing: 12) {
                    Avatar(photo: store.profile.photo, size: 38)
                    Text("Racconta una vacanza intera").font(.subheadline).foregroundStyle(.black)
                    Spacer(minLength: 0)
                    Image(systemName: "rectangle.stack.badge.plus").font(.title3).foregroundStyle(RoamStyle.red)
                }.padding(.horizontal, 12).padding(.vertical, 10).roamGlassCapsule(interactive: true).contentShape(Capsule())
            }.buttonStyle(DiscoveryPressStyle()).padding(.horizontal, 16).padding(.bottom, 16)
            if let issue = store.tripStoriesError {
                VStack(alignment: .leading, spacing: 10) {
                    Text(issue).font(.subheadline)
                    Button("Riprova") { Task { await store.loadTripStories(scope: Self.apiScope(scope)) } }
                }.padding(16)
            }
            if store.tripStories.isEmpty && !store.tripStoriesLoading && store.tripStoriesError == nil {
                if scope == "Seguiti" {
                    RoamEmptyState(icon: "person.2", title: "Nessun viaggio dai seguiti", message: "Quando le persone che segui raccontano una vacanza, la trovi qui.").padding(.top, 40)
                } else {
                    RoamEmptyState(icon: "suitcase.rolling", title: scope == "I miei" ? "Racconta il tuo primo viaggio" : "Ancora nessun viaggio",
                                   message: "Un viaggio raccoglie i post di una vacanza in un unico racconto, giorno per giorno.", action: "Crea un viaggio", perform: onCompose).padding(.top, 40)
                }
            }
            ForEach(store.tripStories) { story in
                TripStoryCard(story: story) { onOpen(story) }.padding(.horizontal, 16).padding(.bottom, 16)
            }
            if store.tripStoriesLoading { ProgressView("Carico i viaggi…").frame(maxWidth: .infinity).padding() }
            if store.tripStoriesHasMore && !store.tripStoriesLoading {
                Color.clear.frame(height: 1).onAppear { Task { await store.loadTripStories(scope: Self.apiScope(scope), append: true) } }
            }
        }
        .task(id: scope) { await store.loadTripStories(scope: Self.apiScope(scope)) }
    }
}

// A whole trip: cover, story, map of the places and the posts day by day.
struct TripStoryDetailView: View {
    let initial: TripStory
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var loaded: TripStory?
    @State private var failure: String?
    @State private var openedPostID: String?
    @State private var showingAuthor = false
    @State private var followBusy = false
    @State private var confirmDelete = false
    @State private var deleting = false
    private var story: TripStory {
        guard var value = loaded else { return initial }
        // Saves made from here update the feed copy: keep showing them.
        if let fresh = store.tripStories.first(where: { $0.id == value.id }) {
            for post in fresh.posts { if let i = value.posts.firstIndex(where: { $0.id == post.id }) { value.posts[i] = post } }
        }
        return value
    }
    private var authorPerson: Person? {
        guard !story.mine, let key = story.author_key else { return nil }
        return Person(key: key, name: story.author, photo: story.author_photo)
    }
    private var days: [(title: String, posts: [SocialPost])] {
        let calendar = Calendar.current
        let start = tripDay(story.start_date).map { calendar.startOfDay(for: $0) }
        let it = Locale(identifier: "it_IT")
        var groups: [(Date?, [SocialPost])] = []
        for post in story.posts {
            let day = tripPostDate(post.created_at).map { calendar.startOfDay(for: $0) }
            if let last = groups.last, last.0 == day { groups[groups.count - 1].1.append(post) } else { groups.append((day, [post])) }
        }
        return groups.enumerated().map { index, group in
            guard let day = group.0 else { return ("Tappa \(index + 1)", group.1) }
            let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(it))
            if let start, let n = calendar.dateComponents([.day], from: start, to: day).day, n >= 0, n < story.days { return ("Giorno \(n + 1) · \(date)", group.1) }
            return (date.prefix(1).uppercased() + date.dropFirst(), group.1)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TripMosaic(posts: story.posts, height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Label("Trip", systemImage: "suitcase.rolling.fill").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6).roamGlassCapsule(tint: RoamStyle.red).padding(12)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                    .padding(.horizontal, 16)
                header
                stats
                if story.posts.count > 0 {
                    PostsMapCard(posts: story.posts, title: "La mappa del viaggio") { openedPostID = $0.id }
                }
                if let failure { Text(failure).font(.subheadline).padding(.horizontal, 20) }
                timeline
            }.padding(.top, 8).padding(.bottom, 24)
        }
        .background { GlassBackdrop() }
        .navigationTitle(story.title).roamHeader()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: shareText) { Label("Condividi", systemImage: "square.and.arrow.up") }
                    if story.mine {
                        Divider()
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Elimina viaggio", systemImage: "trash") }
                    }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Altre azioni")
            }
        }
        .task {
            do { loaded = try await store.tripStory(initial.id); failure = nil }
            catch { if loaded == nil { failure = "Non riesco a caricare tutte le tappe. Tira giù per riprovare." } }
        }
        .refreshable { if let fresh = try? await store.tripStory(initial.id) { loaded = fresh; failure = nil } }
        .sheet(isPresented: $showingAuthor) { if let person = authorPerson { PersonSheet(person: person) } }
        .navigationDestination(item: $openedPostID) { id in
            if let post = story.posts.first(where: { $0.id == id }) { SocialPostDetailView(initial: post, place: post.place) }
        }
        .opacity(deleting ? 0.4 : 1).disabled(deleting)
        .confirmationDialog("Eliminare il viaggio?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                deleting = true
                Task { if await store.deleteTripStory(story) { dismiss() }; deleting = false }
            }
            Button("Annulla", role: .cancel) {}
        } message: { Text("Viene rimossa solo la raccolta: i post restano nel Feed e nel Profilo.") }
    }
    private var shareText: String {
        ([story.title, [story.destination, story.dateRange].filter { !$0.isEmpty }.joined(separator: " · "), story.body]
            + story.posts.map { "• \($0.place.name) — \($0.body)" }).filter { !$0.isEmpty }.joined(separator: "\n")
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(story.title).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(.black)
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                Text(story.destination.isEmpty ? (story.posts.first?.place.name ?? "") : story.destination)
                if !story.dateRange.isEmpty { Text("·"); Text(story.dateRange) }
            }.font(.subheadline).foregroundStyle(.black.opacity(0.75))
            HStack(spacing: 10) {
                Button { showingAuthor = true } label: {
                    HStack(spacing: 8) {
                        Avatar(photo: story.mine ? store.profile.photo : story.author_photo, size: 34)
                        Text(story.mine ? store.profile.name : story.author).font(.subheadline.bold()).foregroundStyle(.black)
                    }
                }.buttonStyle(.plain).disabled(authorPerson == nil)
                if let person = authorPerson, !story.following {
                    Text("•").font(.caption).foregroundStyle(.secondary)
                    Button {
                        followBusy = true
                        Task {
                            if (try? await store.setFollowing(person.key, true)) != nil { loaded?.following = true }
                            followBusy = false
                        }
                    } label: { Text("Segui").font(.subheadline.bold()).foregroundStyle(RoamStyle.red) }.buttonStyle(.plain).disabled(followBusy)
                }
                Spacer(minLength: 0)
                Text(postDateLabel(story.created_at)).font(.caption).foregroundStyle(.secondary)
            }
            if !story.body.isEmpty { Text(story.body).font(.body).foregroundStyle(.black).fixedSize(horizontal: false, vertical: true) }
            if story.is_demo == true { Text("Demo · contenuti e immagini generati").font(.caption2).foregroundStyle(.secondary) }
        }.padding(.horizontal, 20)
    }
    private var stats: some View {
        HStack(spacing: 0) {
            ProfileStat(value: story.days, title: story.days == 1 ? "Giorno" : "Giorni")
            ProfileStat(value: story.post_count, title: "Post")
            ProfileStat(value: story.place_count, title: story.place_count == 1 ? "Luogo" : "Luoghi")
        }.roamGlass(24).padding(.horizontal, 16)
    }
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileSectionTitle(title: "Le tappe", icon: "point.topleft.down.to.point.bottomright.curvepath").padding(.bottom, 12)
            if loaded == nil && failure == nil && story.post_count > story.posts.count { ProgressView().frame(maxWidth: .infinity).padding() }
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle().fill(RoamStyle.red).frame(width: 12, height: 12).padding(.top, 4)
                        if index < days.count - 1 { Rectangle().fill(RoamStyle.red.opacity(0.25)).frame(width: 2) }
                    }.frame(width: 12)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(day.title).font(.subheadline.bold()).foregroundStyle(.black).accessibilityAddTraits(.isHeader)
                        ForEach(day.posts) { post in
                            SocialPostPreview(post: post, place: post.place) { openedPostID = post.id }
                        }
                    }.padding(.bottom, 20)
                }.padding(.leading, 20).padding(.trailing, 16)
            }
        }
    }
}

// New trip: title, dates and story, then the posts it collects.
struct TripStoryComposer: View {
    let onPublished: (TripStory) -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var destination = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var datesEdited = false
    @State private var text = ""
    @State private var selected: [String] = []
    @State private var publishing = false
    @State private var failure: String?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    private var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selected.count >= 2 && end >= start }
    var body: some View {
        NavigationStack {
            Form { Group {
                Section {
                    TextField("Titolo, es. Weekend a Lisbona", text: $title)
                    TextField("Destinazione", text: $destination)
                    DatePicker("Partenza", selection: Binding(get: { start }, set: { start = $0; datesEdited = true; if end < $0 { end = $0 } }), displayedComponents: .date)
                    DatePicker("Ritorno", selection: Binding(get: { end }, set: { end = $0; datesEdited = true }), in: start..., displayedComponents: .date)
                } header: { Text("Il viaggio") }
                Section {
                    TextField("Com’è andata? Racconta la vacanza…", text: $text, axis: .vertical).lineLimit(3...8)
                    Text("\(text.count)/3000").font(.caption).foregroundStyle(text.count > 3000 ? RoamStyle.red : .black)
                } header: { Text("Il racconto") }
                Section {
                    if !store.myPostsLoaded && store.myPosts.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                    else if store.myPosts.count < 2 {
                        Text("Servono almeno due post per creare un viaggio. Pubblica le tappe della vacanza nel Feed, poi raccoglile qui.").foregroundStyle(.black)
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(store.myPosts) { post in
                                let index = selected.firstIndex(of: post.id)
                                Button { toggle(post) } label: {
                                    PostThumbnail(post: post)
                                        .overlay { if index != nil { Rectangle().fill(.white.opacity(0.25)) } }
                                        .overlay(alignment: .topTrailing) {
                                            ZStack {
                                                Circle().fill(index != nil ? RoamStyle.red : .black.opacity(0.25)).overlay(Circle().stroke(.white, lineWidth: 2))
                                                if let index { Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white) }
                                            }.frame(width: 24, height: 24).padding(6)
                                        }
                                }.buttonStyle(.plain)
                                    .accessibilityLabel("\(post.place.name)\(index != nil ? ", selezionato" : "")")
                            }
                        }.listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    }
                } header: { Text(selected.isEmpty ? "Le tappe" : "Le tappe · \(selected.count) selezionati") }
                footer: { Text("Scegli almeno due dei tuoi post: nel viaggio appariranno in ordine di data, giorno per giorno.") }
                if let failure { Section { Text(failure).foregroundStyle(.red) } }
            }.listRowBackground(GlassRowBackground())
            }.disabled(publishing).roamGlassForm().listSectionSeparator(.hidden).tint(RoamStyle.red)
                .navigationTitle("Nuovo viaggio").roamHeader()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(publishing) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { publish() } label: { if publishing { ProgressView() } else { Text("Pubblica").bold() } }.disabled(!valid || publishing || text.count > 3000)
                    }
                }.interactiveDismissDisabled(publishing)
                .task { if !store.myPostsLoaded { await store.loadMyPosts() } }
        }
    }
    private func toggle(_ post: SocialPost) {
        if let i = selected.firstIndex(of: post.id) { selected.remove(at: i) } else { selected.append(post.id) }
        guard !datesEdited else { return }
        // Until the user picks dates, they follow the chosen posts.
        let dates = store.myPosts.filter { selected.contains($0.id) }.compactMap { tripPostDate($0.created_at) }
        if let first = dates.min(), let last = dates.max() { start = first; end = last }
    }
    private func publish() {
        publishing = true; failure = nil
        Task {
            defer { publishing = false }
            do {
                let story = try await store.publishTripStory(title: title.trimmingCharacters(in: .whitespacesAndNewlines), destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
                                                             start: start, end: end, body: text, posts: selected)
                onPublished(story); dismiss()
            } catch { failure = error.localizedDescription }
        }
    }
}
