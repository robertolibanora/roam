import SwiftUI
import MapKit

// MARK: - Direct messages (Instagram-style) and follows

struct DMPreview: Decodable, Hashable { let body: String; let mine: Bool; let created_at: String; let kind: String }
struct Conversation: Decodable, Identifiable, Hashable {
    let id: String
    let peer: Person
    let pinned: Bool
    let last: DMPreview?
    var unread: Int
    let updated_at: String
}
struct DirectMessage: Decodable, Identifiable {
    var id: String
    var body: String
    var mine: Bool
    var created_at: String
    var liked: Bool
    var post: SocialPost?
    var post_missing: Bool?
    var places: [Place]
    var posts: [SocialPost]
}
struct DMThread: Decodable { let peer: Person; let peer_read_at: String?; let messages: [DirectMessage] }
struct UnreadResponse: Decodable { let count: Int }
struct LikedResponse: Decodable { let liked: Bool }

enum ChatTime {
    static func date(_ value: String) -> Date? {
        // Python's isoformat has microseconds: keep three digits for ISO8601DateFormatter.
        let trimmed = value.replacingOccurrences(of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
        let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: trimmed) ?? ISO8601DateFormatter().date(from: trimmed)
    }
    /// "ora", "5 min", "3 h", "2 g", "4 sett." like the Instagram inbox.
    static func ago(_ value: String) -> String {
        guard let date = date(value) else { return "" }
        let s = max(0, Date().timeIntervalSince(date))
        switch s {
        case ..<60: return "ora"
        case ..<3600: return "\(Int(s / 60)) min"
        case ..<86400: return "\(Int(s / 3600)) h"
        case ..<(7 * 86400): return "\(Int(s / 86400)) g"
        default: return "\(Int(s / (7 * 86400))) sett."
        }
    }
    static func separator(_ value: String) -> String {
        guard let date = date(value) else { return "" }
        let time = date.formatted(.dateTime.hour().minute())
        if Calendar.current.isDateInToday(date) { return "Oggi \(time)" }
        if Calendar.current.isDateInYesterday(date) { return "Ieri \(time)" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "it_IT"))) + " " + time
    }
}

struct RoamAvatar: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [RoamStyle.red, Color(red: 0.98, green: 0.42, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoamMark().stroke(.white, style: StrokeStyle(lineWidth: max(1.5, size / 22), lineCap: .round, lineJoin: .round)).padding(size * 0.24)
        }.frame(width: size, height: size).accessibilityLabel("ROAM")
    }
}

struct TypingBubble: View {
    @State private var phase = 0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in Circle().fill(Color.secondary).frame(width: 7, height: 7).opacity(phase == i ? 1 : 0.35) }
        }
        .padding(.horizontal, 16).padding(.vertical, 14).roamGlassCapsule()
        .task { while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(350)); phase = (phase + 1) % 3 } }
        .accessibilityLabel("Sta scrivendo")
    }
}

/// Floating glass field; a red send button appears once there is text.
struct MessageComposer: View {
    @Binding var text: String
    var placeholder = "Messaggio…"
    var disabled = false
    let send: () -> Void
    private var empty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical).lineLimit(1...5).font(.body)
                .padding(.vertical, 11).padding(.leading, 16)
                .submitLabel(.send).onSubmit { if !empty && !disabled { send() } }
            if !empty {
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.headline).foregroundStyle(.white).frame(width: 36, height: 36).background(RoamStyle.red, in: Circle())
                }.disabled(disabled).padding(.trailing, 5).padding(.bottom, 4).transition(.scale.combined(with: .opacity)).accessibilityLabel("Invia")
            }
        }
        .frame(minHeight: 44)
        .roamGlass(24)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .animation(.easeOut(duration: 0.15), value: empty)
    }
}

// MARK: Inbox

struct InboxView: View {
    @EnvironmentObject private var store: Store
    @State private var query = ""
    @State private var composing = false
    @State private var opened: Conversation?
    @State private var loaded = false
    @State private var groupsLoaded = false
    @State private var planningTrip = false
    @State private var openedGroup: TripGroup?
    @AppStorage("inboxScope") private var scope = "Messaggi"
    private var shown: [Conversation] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? store.conversations : store.conversations.filter { $0.peer.name.localizedCaseInsensitiveContains(q) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    RoamTabs(options: ["Messaggi", "Viaggi di gruppo"], selection: $scope).padding(.horizontal, 16).padding(.bottom, 14)
                    if scope == "Viaggi di gruppo" {
                        GroupsSection(loaded: groupsLoaded) { planningTrip = true }
                    } else {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Cerca", text: $query).autocorrectionDisabled()
                    }.padding(.horizontal, 16).padding(.vertical, 12).roamGlassCapsule()
                        .padding(.horizontal, 16).padding(.bottom, 16)
                    Text("CONVERSAZIONI").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(RoamStyle.red).padding(.horizontal, 20).padding(.bottom, 8)
                    if !loaded && store.conversations.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(40) }
                    VStack(spacing: 10) {
                        ForEach(shown) { conversation in
                            NavigationLink(value: conversation) { ConversationRow(conversation: conversation) }.buttonStyle(DiscoveryPressStyle())
                        }
                    }.padding(.horizontal, 16)
                    if loaded && store.conversations.count <= 1 && query.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "paperplane.circle").font(.system(size: 44)).foregroundStyle(RoamStyle.red)
                            Text("Scrivi ai tuoi compagni di viaggio").font(.subheadline.bold())
                            Text("Apri il profilo di un viaggiatore e tocca Messaggio, oppure invia un post con l’aeroplanino.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button { composing = true } label: {
                                Label("Nuovo messaggio", systemImage: "square.and.pencil").font(.subheadline.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 18).frame(height: 40).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                            }.buttonStyle(DiscoveryPressStyle()).padding(.top, 4)
                        }.padding(28).frame(maxWidth: .infinity).roamGlass(26).padding(16)
                    }
                    }
                }.padding(.top, 4)
            }
            .background { GlassBackdrop() }
            .navigationTitle("Messaggi").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { if scope == "Viaggi di gruppo" { planningTrip = true } else { composing = true } } label: {
                        Image(systemName: scope == "Viaggi di gruppo" ? "airplane.departure" : "square.and.pencil")
                    }.accessibilityLabel(scope == "Viaggi di gruppo" ? "Nuovo viaggio di gruppo" : "Nuovo messaggio")
                }
            }
            .navigationDestination(for: Conversation.self) { destination($0) }
            .navigationDestination(item: $opened) { destination($0) }
            .navigationDestination(for: TripGroup.self) { GroupThreadView(group: $0) }
            .navigationDestination(item: $openedGroup) { GroupThreadView(group: $0) }
            .sheet(isPresented: $planningTrip) { GroupOnboardingView { openedGroup = $0 } }
            .sheet(isPresented: $composing) { NewMessageView { conversation in opened = conversation } }
            .refreshable { await store.loadConversations(); await store.loadGroups() }
            .task {
                while !Task.isCancelled {
                    await store.loadGroups(); groupsLoaded = true
                    await store.loadConversations(); loaded = true
                    try? await Task.sleep(for: .seconds(6))
                }
            }
        }
    }
    @ViewBuilder private func destination(_ conversation: Conversation) -> some View {
        if conversation.pinned { RoamChatView(conversation: conversation) } else { ThreadView(conversation: conversation) }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    private var unread: Bool { conversation.unread > 0 }
    private var preview: String {
        guard let last = conversation.last else { return conversation.pinned ? "Il tuo assistente di viaggio · chiedimi un consiglio" : "" }
        if last.kind == "post" { return last.mine ? "Hai inviato un post" : "Ha inviato un post" }
        if unread && conversation.unread > 1 { return "\(conversation.unread) nuovi messaggi" }
        return (last.mine ? "Tu: " : "") + last.body.replacingOccurrences(of: "\n", with: " ")
    }
    var body: some View {
        HStack(spacing: 12) {
            if conversation.pinned { RoamAvatar(size: 52) } else { PersonBadge(person: conversation.peer, size: 52) }
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.peer.name).font(.subheadline.weight(unread ? .bold : .semibold)).foregroundStyle(.black).lineLimit(1)
                HStack(spacing: 4) {
                    Text(preview).lineLimit(1)
                    if let last = conversation.last { Text("· " + ChatTime.ago(last.created_at)).layoutPriority(1) }
                }.font(.subheadline.weight(unread ? .semibold : .regular)).foregroundStyle(unread ? Color.primary : Color.secondary)
            }
            Spacer(minLength: 8)
            if conversation.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(RoamStyle.red).rotationEffect(.degrees(45)).accessibilityLabel("Fissata") }
            else if unread {
                Text("\(conversation.unread)").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 7).frame(minWidth: 22, minHeight: 22).background(RoamStyle.red, in: Capsule()).accessibilityLabel("\(conversation.unread) non letti")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
        .roamGlass(24, interactive: true)
        .overlay { if conversation.pinned { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(RoamStyle.red.opacity(0.35), lineWidth: 1) } }
    }
}

struct PersonPickerRow: View {
    let person: Person
    var body: some View {
        HStack(spacing: 12) {
            PersonBadge(person: person, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.subheadline.bold()).lineLimit(1)
                Text(person.has_account ? (person.is_following ? "Segui già" : "\(person.posts) post") : "Profilo dimostrativo").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct NewMessageView: View {
    let onOpen: (Conversation) -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var people: [Person] = []
    @State private var opening: String?
    var body: some View {
        NavigationStack {
            List {
                ForEach(people.filter { !$0.mine }) { person in
                    Button { Task { await open(person) } } label: {
                        HStack { PersonPickerRow(person: person); if opening == person.key { ProgressView() } }
                    }.buttonStyle(.plain).roamGlassRow()
                }
            }
            .listStyle(.plain).roamGlassForm()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca")
            .navigationTitle("Nuovo messaggio").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } } }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 300))
                if let found = try? await store.searchPeople(query), !Task.isCancelled { people = found }
            }
        }
    }
    private func open(_ person: Person) async {
        opening = person.key; defer { opening = nil }
        do { let c = try await store.openConversation(with: person.key); dismiss(); onOpen(c) }
        catch { store.error = error.localizedDescription }
    }
}

// MARK: Thread

struct ThreadView: View {
    let conversation: Conversation
    @EnvironmentObject private var store: Store
    @State private var peer: Person?
    @State private var messages: [DirectMessage] = []
    @State private var peerReadAt: String?
    @State private var loaded = false
    @State private var draft = ""
    @State private var sending = false
    @State private var openedPostID: String?
    private var person: Person { peer ?? conversation.peer }
    private var seenID: String? {
        guard let read = peerReadAt, let last = messages.last, last.mine, read >= last.created_at else { return nil }
        return last.id
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        header.padding(.bottom, 20)
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if showsTime(index) {
                                Text(ChatTime.separator(message.created_at)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                                    .padding(.horizontal, 10).padding(.vertical, 5).roamGlassCapsule().padding(.vertical, 10)
                            }
                            MessageBubble(message: message, peer: person, lastInGroup: lastInGroup(index), onLike: { Task { await like(message) } }, onPost: { openedPostID = $0.id })
                                .padding(.top, index > 0 && messages[index - 1].mine != message.mine ? 8 : 0)
                                .id(message.id)
                            if message.id == seenID {
                                Text("Visualizzato").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 2)
                            }
                        }
                    }.padding(.horizontal, 12).padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.last?.id) { _, id in if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
            }
            if !person.has_account && loaded {
                Label("\(person.name) è un profilo dimostrativo: non può rispondere.", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6).roamGlassCapsule().padding(.top, 6)
            }
            MessageComposer(text: $draft, disabled: sending) { Task { await send() } }
        }
        .background { GlassBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationLink { PersonView(person: person) } label: {
                    HStack(spacing: 10) {
                        PersonBadge(person: person, size: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(person.name).font(.subheadline.bold()).foregroundStyle(.primary).lineLimit(1)
                            Text(person.has_account ? "Visualizza profilo" : "Profilo dimostrativo").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
        .navigationDestination(item: $openedPostID) { id in
            if let post = messages.first(where: { $0.post?.id == id })?.post {
                SocialPostDetailView(initial: post, place: post.place)
            }
        }
        .task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
    /// Instagram shows the profile at the top of every conversation.
    private var header: some View {
        VStack(spacing: 6) {
            PersonBadge(person: person, size: 88).padding(5).roamGlassCircle()
            Text(person.name).font(.system(.headline, design: .rounded, weight: .bold))
            if peer != nil {
                Text("\(person.followers) follower · \(person.posts) post").font(.caption).foregroundStyle(.secondary)
                if person.follows_you { Text("Ti segue").font(.caption).foregroundStyle(.secondary) }
            }
            NavigationLink { PersonView(person: person) } label: {
                Text("Visualizza profilo").font(.caption.bold()).foregroundStyle(.black).padding(.horizontal, 16).padding(.vertical, 9)
                    .roamGlassCapsule(interactive: true)
            }.buttonStyle(.plain).padding(.top, 6)
        }.frame(maxWidth: .infinity).padding(.vertical, 20).roamGlass(28).padding(.horizontal, 20).padding(.top, 8)
    }
    private func showsTime(_ i: Int) -> Bool {
        guard i > 0 else { return true }
        guard let a = ChatTime.date(messages[i - 1].created_at), let b = ChatTime.date(messages[i].created_at) else { return false }
        return b.timeIntervalSince(a) > 3600
    }
    private func lastInGroup(_ i: Int) -> Bool { i == messages.count - 1 || messages[i + 1].mine != messages[i].mine || showsTime(i + 1) }
    private func load() async {
        do {
            let thread: DMThread = try await store.request("/dm/conversations/\(conversation.id)/messages")
            peer = thread.peer; peerReadAt = thread.peer_read_at
            if thread.messages.map(\.id) != messages.map(\.id) || thread.messages.map(\.liked) != messages.map(\.liked) { messages = thread.messages }
            if let i = store.conversations.firstIndex(where: { $0.id == conversation.id }), store.conversations[i].unread > 0 {
                store.conversations[i].unread = 0; store.unreadChats = store.conversations.filter { $0.unread > 0 }.count
            }
        } catch { }
        loaded = true
    }
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""; sending = true; defer { sending = false }
        let temp = DirectMessage(id: "pending-" + UUID().uuidString, body: text, mine: true, created_at: ISO8601DateFormatter().string(from: Date()), liked: false, post: nil, post_missing: nil, places: [], posts: [])
        withAnimation(.easeOut(duration: 0.2)) { messages.append(temp) }
        do {
            let sent = try await store.sendMessage(conversation.id, body: text)
            if let i = messages.firstIndex(where: { $0.id == temp.id }) { messages[i] = sent }
        } catch {
            messages.removeAll { $0.id == temp.id }; draft = text
            store.error = "Messaggio non inviato. Riprova."
        }
    }
    private func like(_ message: DirectMessage) async {
        guard !message.mine, let i = messages.firstIndex(where: { $0.id == message.id }) else { return }
        let target = !message.liked
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { messages[i].liked = target }
        do {
            let body = try JSONSerialization.data(withJSONObject: ["liked": target])
            let _: LikedResponse = try await store.request("/dm/messages/\(message.id)/liked", method: "PUT", body: body)
        } catch { if let i = messages.firstIndex(where: { $0.id == message.id }) { messages[i].liked = !target } }
    }
}

struct MessageBubble: View {
    let message: DirectMessage
    let peer: Person
    let lastInGroup: Bool
    let onLike: () -> Void
    let onPost: (SocialPost) -> Void
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.mine { Spacer(minLength: 60) }
            else {
                Group { if lastInGroup { PersonBadge(person: peer, size: 28) } else { Color.clear } }.frame(width: 28, height: 28)
            }
            VStack(alignment: message.mine ? .trailing : .leading, spacing: 4) {
                if let post = message.post { SocialPostPreview(post: post, place: post.place, compact: true) { onPost(post) }.frame(width: 240) }
                else if message.post_missing == true {
                    Text("Post non più disponibile").font(.footnote).italic().foregroundStyle(.secondary).padding(12).roamGlass(18)
                }
                if !message.body.isEmpty {
                    Text(message.body).font(.body).foregroundStyle(message.mine ? .white : .black)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .roamGlass(20, tint: message.mine ? RoamStyle.red : nil)
                        .opacity(message.id.hasPrefix("pending-") ? 0.6 : 1)
                        .textSelection(.enabled)
                }
            }
            .overlay(alignment: message.mine ? .bottomLeading : .bottomTrailing) {
                if message.liked {
                    Text("❤️").font(.caption2).padding(3).background(Color.white, in: Circle()).shadow(color: .black.opacity(0.12), radius: 2)
                        .offset(x: message.mine ? -8 : 8, y: 10).transition(.scale)
                }
            }
            .padding(.bottom, message.liked ? 12 : 0)
            .onTapGesture(count: 2) { onLike() }
            .contextMenu {
                if !message.mine { Button { onLike() } label: { Label(message.liked ? "Togli il cuore" : "Metti un cuore", systemImage: "heart") } }
                if !message.body.isEmpty { Button { UIPasteboard.general.string = message.body } label: { Label("Copia", systemImage: "doc.on.doc") } }
            }
            if !message.mine { Spacer(minLength: 60) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel((message.mine ? "Tu: " : "\(peer.name): ") + (message.post.map { "post su \($0.place.name). " } ?? "") + message.body + (message.liked ? ". Piace" : ""))
    }
}

// MARK: Share a post in a chat (the paper plane)

struct SendPostSheet: View {
    let post: SocialPost
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var people: [Person] = []
    @State private var sent = Set<String>()
    @State private var busy: String?
    @State private var note = ""
    private var recent: [Person] { store.conversations.filter { !$0.pinned }.map(\.peer) }
    private var shown: [Person] {
        var seen = Set<String>()
        let list = query.trimmingCharacters(in: .whitespaces).isEmpty ? recent + people : people
        return list.filter { !$0.mine && seen.insert($0.key).inserted }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List(shown) { person in
                    HStack {
                        PersonPickerRow(person: person)
                        if busy == person.key { ProgressView() }
                        else {
                            Button(sent.contains(person.key) ? "Inviato" : "Invia") { Task { await send(to: person) } }
                                .font(.subheadline.bold()).buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(sent.contains(person.key) ? Color(.systemGray4) : RoamStyle.red)
                                .disabled(sent.contains(person.key))
                        }
                    }.roamGlassRow()
                }.listStyle(.plain).scrollContentBackground(.hidden)
                TextField("Scrivi un messaggio…", text: $note).padding(14).roamGlass(22).padding(12)
            }
            .background { GlassBackdrop() }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca")
            .navigationTitle("Invia a").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
            .task { if store.conversations.isEmpty { await store.loadConversations() } }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 300))
                if let found = try? await store.searchPeople(query), !Task.isCancelled { people = found }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func send(to person: Person) async {
        busy = person.key; defer { busy = nil }
        do {
            let conversation = try await store.openConversation(with: person.key)
            try await store.sendMessage(conversation.id, post: post.id)
            let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { try await store.sendMessage(conversation.id, body: text) }
            sent.insert(person.key)
            await store.loadConversations()
        } catch { store.error = "Invio non riuscito. Riprova." }
    }
}

// MARK: Profiles and connections

struct PersonSheet: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            PersonView(person: person)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() }.foregroundStyle(RoamStyle.red) } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible).presentationCornerRadius(32)
    }
}

/// Followers or followed travellers, each with its own Segui button.
struct ConnectionsView: View {
    let person: Person
    let kind: String
    @EnvironmentObject private var store: Store
    @State private var people: [Person] = []
    @State private var loaded = false
    @State private var failure = false
    var body: some View {
        List {
            if failure { Button("Elenco non disponibile. Riprova") { Task { await load() } } }
            else if loaded && people.isEmpty {
                Text(kind == "followers" ? "Ancora nessun follower." : "Non segue ancora nessuno.").foregroundStyle(.secondary)
            }
            ForEach($people) { $p in
                HStack {
                    NavigationLink { PersonView(person: p) } label: { PersonPickerRow(person: p) }
                    if !p.mine {
                        Button(p.is_following ? "Segui già" : "Segui") {
                            Task { if let updated = try? await store.setFollowing(p.key, !p.is_following) { p = updated } }
                        }
                        .font(.caption.bold()).buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        .tint(p.is_following ? Color(.systemGray5) : RoamStyle.red).foregroundStyle(p.is_following ? Color.black : .white)
                    }
                }.roamGlassRow()
            }
        }
        .listStyle(.plain).roamGlassForm()
        .overlay { if !loaded { ProgressView() } }
        .navigationTitle(kind == "followers" ? "Follower" : "Seguiti").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }
    private func load() async {
        do { people = try await store.connections(of: person.key, kind: kind); failure = false }
        catch { if !Task.isCancelled { failure = true } }
        loaded = true
    }
}

// MARK: - Group trips: organise a holiday together, then ROAM plans it

struct GroupPreview: Decodable, Hashable { let body: String; let author: String; let kind: String; let created_at: String }
struct PlanStop: Decodable, Hashable, Identifiable {
    let place_id, name, category: String
    let latitude, longitude: Double
    let description: String
    let note: String
    var id: String { place_id }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var place: Place {
        let symbol = ["Parco": "leaf.fill", "Ristorante": "fork.knife", "Caffè": "cup.and.saucer.fill", "Negozio": "bag.fill"][category] ?? "building.columns.fill"
        return Place(id: place_id, name: name, category: category, latitude: latitude, longitude: longitude, description: description, symbol: symbol, distance: 0)
    }
    var mapItem: MKMapItem { let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate)); item.name = name; return item }
}
struct PlanDay: Decodable, Hashable { let title: String; let stops: [PlanStop] }
struct TripPlan: Decodable, Hashable {
    let summary: String
    let days: [PlanDay]
    let destination: String?
    let start_date: String?
    let end_date: String?
    let mode: String?
}
struct TripGroup: Decodable, Identifiable, Hashable {
    let id, title, destination, start_date, end_date, updated_at: String
    let latitude, longitude: Double?
    let members: [Person]
    let last: GroupPreview?
    var unread: Int
    let has_plan: Bool
    let mine: Bool
}
struct GroupMessage: Decodable, Identifiable {
    let id, body, kind, created_at: String
    let mine: Bool
    let sender: Person?
    let plan: TripPlan?
}
struct GroupDetail: Decodable {
    let id, title, destination, start_date, end_date: String
    let latitude, longitude: Double?
    let members: [Person]
    let messages: [GroupMessage]
    let plan: TripPlan?
    let voices: [String]
    let mine: Bool
    var summary: TripGroup { TripGroup(id: id, title: title, destination: destination, start_date: start_date, end_date: end_date, updated_at: "", latitude: latitude, longitude: longitude, members: members, last: nil, unread: 0, has_plan: plan != nil, mine: mine) }
}

enum TripDates {
    static func date(_ value: String) -> Date? {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: value)
    }
    static func string(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func range(_ start: String, _ end: String) -> String {
        guard let a = date(start), let b = date(end) else { return "" }
        let style = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT"))
        return a == b ? a.formatted(style) : "\(a.formatted(style)) – \(b.formatted(style))"
    }
    static func days(_ start: String, _ end: String) -> Int {
        guard let a = date(start), let b = date(end) else { return 1 }
        return max(1, (Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0) + 1)
    }
}

/// Overlapping portraits of the group, like a travel crew.
struct MemberStack: View {
    let members: [Person]
    var size: CGFloat = 34
    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(members.prefix(4)) { PersonBadge(person: $0, size: size).overlay(Circle().stroke(.white, lineWidth: 2)) }
            if members.count > 4 {
                Text("+\(members.count - 4)").font(.caption2.bold()).foregroundStyle(RoamStyle.red).frame(width: size, height: size).roamGlassCircle()
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(members.map(\.name).joined(separator: ", "))
    }
}

struct GroupRow: View {
    let group: TripGroup
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Image(systemName: "airplane").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52).roamGlassCircle(tint: RoamStyle.red)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.title).font(.subheadline.bold()).foregroundStyle(.black).lineLimit(1)
                    if group.has_plan {
                        Label("Piano", systemImage: "map.fill").font(.caption2.bold()).foregroundStyle(RoamStyle.red)
                            .padding(.horizontal, 7).padding(.vertical, 3).roamGlassCapsule()
                    }
                }
                Text("\(group.destination) · \(TripDates.range(group.start_date, group.end_date))").font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                if let last = group.last {
                    Text((last.author.isEmpty ? "" : last.author + ": ") + last.body.replacingOccurrences(of: "\n", with: " "))
                        .font(.caption).foregroundStyle(group.unread > 0 ? Color.black : Color.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 8) {
                MemberStack(members: group.members, size: 24)
                if group.unread > 0 {
                    Text("\(group.unread)").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 7).frame(minWidth: 22, minHeight: 22).background(RoamStyle.red, in: Capsule())
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
        .roamGlass(24, interactive: true)
    }
}

/// The "Viaggi di gruppo" side of the inbox.
struct GroupsSection: View {
    @EnvironmentObject private var store: Store
    let loaded: Bool
    let onCreate: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onCreate) {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(.white).frame(width: 52, height: 52).roamGlassCircle(tint: RoamStyle.red)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Organizza un viaggio insieme").font(.headline).foregroundStyle(.black)
                        Text("Create il gruppo, discutete e alla fine ROAM scrive il piano con il percorso.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "plus").font(.headline).foregroundStyle(RoamStyle.red)
                }.padding(14).roamGlass(26, interactive: true)
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(RoamStyle.red.opacity(0.35), lineWidth: 1))
            }.buttonStyle(DiscoveryPressStyle())
            if !store.groups.isEmpty {
                Text("I VOSTRI VIAGGI").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(RoamStyle.red).padding(.horizontal, 4).padding(.top, 8)
            }
            if !loaded && store.groups.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(30) }
            ForEach(store.groups) { group in
                NavigationLink(value: group) { GroupRow(group: group) }.buttonStyle(DiscoveryPressStyle())
            }
        }.padding(.horizontal, 16)
    }
}

// MARK: Onboarding

struct GroupOnboardingView: View {
    let onCreated: (TripGroup) -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var destinationText = ""
    @State private var destination: CityResult?
    @State private var locating = false
    @State private var locateNote: String?
    @State private var title = ""
    @State private var start = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 16, to: Date()) ?? Date()
    @State private var query = ""
    @State private var people: [Person] = []
    @State private var invited: [Person] = []
    @State private var idea = ""
    @State private var creating = false
    @State private var failure: String?
    private let steps = ["Dove", "Quando", "Con chi", "L’idea"]
    private let ideas = ["Musei e arte", "Cibo locale", "Natura e passeggiate", "Relax", "Vita notturna", "Shopping", "Budget contenuto"]
    private var days: Int { max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end)).day ?? 0) + 1) }
    private var canContinue: Bool {
        switch step {
        case 0: return destination != nil
        case 1: return end >= start && days <= 31
        default: return true
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    progress
                    Group {
                        switch step {
                        case 0: whereStep
                        case 1: whenStep
                        case 2: whoStep
                        default: ideaStep
                        }
                    }.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    if let failure { Label(failure, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(RoamStyle.red) }
                }.padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { controls }
            .background { GlassBackdrop() }
            .navigationTitle("Nuovo viaggio di gruppo").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.disabled(creating) } }
            .interactiveDismissDisabled(creating)
            .task(id: destinationText) { await locate() }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 300))
                if let found = try? await store.searchPeople(query), !Task.isCancelled { people = found.filter { $0.has_account && !$0.mine } }
            }
        }
    }
    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                VStack(spacing: 6) {
                    Capsule().fill(i <= step ? RoamStyle.red : .black.opacity(0.12)).frame(height: 4)
                    Text(steps[i]).font(.caption2.weight(i == step ? .bold : .medium)).foregroundStyle(i == step ? RoamStyle.red : .secondary)
                }
            }
        }.padding(12).roamGlass(20).accessibilityElement(children: .ignore).accessibilityLabel("Passo \(step + 1) di \(steps.count): \(steps[step])")
    }
    private func stepTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(.black)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }
    private var whereStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Dove andate?", "Una città, un’isola, una regione o un paese: ROAM cercherà lì i luoghi del piano.")
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(RoamStyle.red)
                TextField("Es. Tokyo, Spagna, Sicilia…", text: $destinationText).font(.body).autocorrectionDisabled().submitLabel(.next)
                if locating { ProgressView() }
            }.padding(.horizontal, 16).padding(.vertical, 14).roamGlassCapsule()
            if let destination {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark").font(.headline).foregroundStyle(.white).frame(width: 40, height: 40).roamGlassCircle(tint: RoamStyle.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destination.name).font(.headline).foregroundStyle(.black)
                        Text([destination.region, destination.country].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(12).roamGlass(22)
                Map(initialPosition: .region(.init(center: destination.coordinate, span: .init(latitudeDelta: 0.25, longitudeDelta: 0.25)))) {
                    Marker(destination.name, coordinate: destination.coordinate).tint(RoamStyle.red)
                }.frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).padding(6).roamGlass(26).id(destination.name)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nome del gruppo").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("Viaggio a \(destination.name)", text: $title).padding(.horizontal, 16).padding(.vertical, 12).roamGlassCapsule()
                }
            } else if destinationText.trimmingCharacters(in: .whitespaces).count >= 2 && !locating {
                Text(locateNote ?? "Non trovo “\(destinationText)”. Prova con la città, la regione o il paese.").font(.caption).foregroundStyle(locateNote == nil ? Color.secondary : RoamStyle.red)
            }
        }
    }
    private var whenStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Quando?", "ROAM preparerà un piano giorno per giorno, fino a 7 giornate.")
            VStack(spacing: 0) {
                DatePicker("Partenza", selection: $start, in: Date()..., displayedComponents: .date).padding(14)
                Rectangle().fill(.black.opacity(0.06)).frame(height: 1).padding(.leading, 14)
                DatePicker("Ritorno", selection: $end, in: start..., displayedComponents: .date).padding(14)
            }.font(.subheadline.weight(.semibold)).tint(RoamStyle.red).roamGlass(22)
            Label(days == 1 ? "1 giorno" : "\(days) giorni" + (days > 7 ? " · il piano coprirà i primi 7" : ""), systemImage: "calendar")
                .font(.subheadline.weight(.semibold)).foregroundStyle(RoamStyle.red).padding(.horizontal, 12).padding(.vertical, 8).roamGlassCapsule()
        }
        .onChange(of: start) { _, value in if end < value { end = value } }
    }
    private var whoStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Con chi?", "Invita i compagni di viaggio con un account Roam. Potrai aggiungerne altri dopo.")
            if !invited.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(invited) { person in
                            Button { invited.removeAll { $0.key == person.key } } label: {
                                HStack(spacing: 6) { PersonBadge(person: person, size: 24); Text(person.name).font(.caption.bold()); Image(systemName: "xmark").font(.caption2.bold()) }
                                    .foregroundStyle(.white).padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4).roamGlassCapsule(tint: RoamStyle.red)
                            }.buttonStyle(.plain).accessibilityLabel("Rimuovi \(person.name)")
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(RoamStyle.red)
                TextField("Cerca viaggiatori", text: $query).autocorrectionDisabled()
            }.padding(.horizontal, 16).padding(.vertical, 12).roamGlassCapsule()
            VStack(spacing: 8) {
                ForEach(people.prefix(12)) { person in
                    let on = invited.contains { $0.key == person.key }
                    Button { if on { invited.removeAll { $0.key == person.key } } else { invited.append(person) } } label: {
                        HStack { PersonPickerRow(person: person); Image(systemName: on ? "checkmark.circle.fill" : "plus.circle").font(.title3).foregroundStyle(RoamStyle.red) }
                            .padding(.horizontal, 12).padding(.vertical, 10).roamGlass(20, interactive: true)
                    }.buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                }
                if people.isEmpty { Text("Nessun viaggiatore con account trovato.").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private var ideaStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Da dove partiamo?", "Il primo messaggio del gruppo. Poi discutete insieme: ROAM pianifica solo quando glielo chiedete.")
            TextField("Cosa vi piacerebbe fare?", text: $idea, axis: .vertical).lineLimit(3...6).padding(16).roamGlass(22)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(ideas, id: \.self) { item in
                    Button { idea = idea.isEmpty ? item : idea + ", " + item.lowercased() } label: {
                        Text(item).font(.caption.weight(.semibold)).foregroundStyle(RoamStyle.red).frame(maxWidth: .infinity).padding(.vertical, 9).roamGlassCapsule(interactive: true)
                    }.buttonStyle(.plain)
                }
            }
            if let destination {
                VStack(alignment: .leading, spacing: 8) {
                    Label(title.isEmpty ? "Viaggio a \(destination.name)" : title, systemImage: "airplane").font(.headline).foregroundStyle(.black)
                    Text("\(destination.name) · \(TripDates.range(TripDates.string(start), TripDates.string(end))) · \(days) giorni").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        MemberStack(members: invited, size: 26)
                        Text(invited.isEmpty ? "Solo tu, per ora" : "Tu e altre \(invited.count) persone").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).roamGlass(22)
            }
        }
    }
    private var controls: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { step -= 1 } } label: {
                    Image(systemName: "chevron.left").font(.headline).foregroundStyle(RoamStyle.red).frame(width: 50, height: 50).roamGlassCircle(interactive: true)
                }.disabled(creating).accessibilityLabel("Indietro")
            }
            Button {
                if step < steps.count - 1 { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { step += 1 } } else { Task { await create() } }
            } label: {
                Group {
                    if creating { ProgressView().tint(.white) }
                    else { Label(step < steps.count - 1 ? "Avanti" : "Crea il gruppo", systemImage: step < steps.count - 1 ? "arrow.right" : "sparkles") }
                }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50)
                    .roamGlassCapsule(interactive: true, tint: canContinue ? RoamStyle.red : RoamStyle.red.opacity(0.4))
            }.disabled(!canContinue || creating)
        }.buttonStyle(DiscoveryPressStyle()).padding(.horizontal, 20).padding(.vertical, 10)
    }
    private func locate() async {
        let text = destinationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { destination = nil; locateNote = nil; return }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        locating = true; defer { locating = false }
        let outcome = await store.geocodeOutcome(text)
        if !Task.isCancelled {
            destination = outcome.place
            locateNote = outcome.place == nil ? outcome.failure : nil
        }
    }
    private func create() async {
        guard let destination else { return }
        creating = true; failure = nil; defer { creating = false }
        do {
            let payload: [String: Any] = ["title": title, "destination": destination.name, "latitude": destination.coordinate.latitude, "longitude": destination.coordinate.longitude,
                                          "start_date": TripDates.string(start), "end_date": TripDates.string(end), "members": invited.map(\.key), "idea": idea]
            let detail: GroupDetail = try await store.request("/groups", method: "POST", body: JSONSerialization.data(withJSONObject: payload))
            await store.loadGroups()
            dismiss(); onCreated(detail.summary)
        } catch { failure = error.localizedDescription }
    }
}

// MARK: Group chat

struct GroupThreadView: View {
    let group: TripGroup
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var detail: GroupDetail?
    @State private var draft = ""
    @State private var sending = false
    @State private var planning = false
    @State private var confirmPlan = false
    @State private var confirmLeave = false
    @State private var addingPeople = false
    @State private var failure: String?
    private var messages: [GroupMessage] { detail?.messages ?? [] }
    private var members: [Person] { detail?.members ?? group.members }
    private var voices: Int { detail?.voices.count ?? 0 }
    private var hasDiscussion: Bool { messages.contains { $0.kind == "text" } }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        header.padding(.bottom, 14)
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            row(message, showsName: index == 0 || messages[index - 1].sender?.key != message.sender?.key || messages[index - 1].kind != "text")
                                .id(message.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if planning {
                            HStack(spacing: 8) {
                                RoamAvatar(size: 28)
                                TypingBubble()
                                Text("ROAM legge la discussione e prepara il piano…").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }.id("planning").padding(.top, 6)
                        }
                    }.padding(.horizontal, 12).padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.last?.id) { _, id in if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
                .onChange(of: planning) { _, now in if now { withAnimation { proxy.scrollTo("planning", anchor: .bottom) } } }
            }
            if let failure { Label(failure, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(RoamStyle.red).padding(.horizontal, 12).padding(.vertical, 6).roamGlassCapsule().padding(.top, 4) }
            planBar
            MessageComposer(text: $draft, placeholder: "Scrivi al gruppo…", disabled: sending) { Task { await send() } }
        }
        .background { GlassBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(detail?.title ?? group.title).font(.subheadline.bold()).lineLimit(1)
                    Text("\(members.count) persone · \(group.destination)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { addingPeople = true } label: { Label("Aggiungi persone", systemImage: "person.badge.plus") }
                    Button(role: .destructive) { confirmLeave = true } label: { Label("Esci dal gruppo", systemImage: "rectangle.portrait.and.arrow.right") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Chiedere a ROAM di pianificare?", isPresented: $confirmPlan, titleVisibility: .visible) {
            Button(detail?.plan == nil ? "Pianifica il viaggio" : "Aggiorna il piano") { Task { await plan() } }
            Button("Continuiamo a discutere", role: .cancel) {}
        } message: { Text("ROAM leggerà tutta la discussione e le preferenze di chi ha scritto, poi proporrà un piano giorno per giorno con il percorso.") }
        .confirmationDialog("Uscire dal gruppo?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Esci", role: .destructive) { Task { await leave() } }
        } message: { Text("Non vedrai più la discussione né il piano. Gli altri potranno continuare.") }
        .sheet(isPresented: $addingPeople) {
            AddGroupMembersView(groupID: group.id, current: Set(members.map(\.key))) { updated in detail = updated }
        }
        .task {
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white).frame(width: 64, height: 64).roamGlassCircle(tint: RoamStyle.red)
            Text(group.destination).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.black)
            Label(TripDates.range(group.start_date, group.end_date) + " · \(TripDates.days(group.start_date, group.end_date)) giorni", systemImage: "calendar")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                MemberStack(members: members, size: 30)
                Button { addingPeople = true } label: {
                    Label("Invita", systemImage: "person.badge.plus").font(.caption.bold()).foregroundStyle(RoamStyle.red).padding(.horizontal, 12).padding(.vertical, 7).roamGlassCapsule(interactive: true)
                }.buttonStyle(.plain)
            }
            Text("Discutete liberamente: ROAM interviene solo quando gli chiedete di pianificare.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 18).padding(.horizontal, 16).roamGlass(28).padding(.horizontal, 8).padding(.top, 8)
    }
    @ViewBuilder private func row(_ message: GroupMessage, showsName: Bool) -> some View {
        switch message.kind {
        case "system":
            Text(message.body).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 6).roamGlassCapsule().padding(.vertical, 8).frame(maxWidth: .infinity)
        case "plan":
            if let plan = message.plan { GroupPlanCard(plan: plan, created: message.created_at).padding(.vertical, 8) }
        default:
            HStack(alignment: .bottom, spacing: 8) {
                if message.mine { Spacer(minLength: 60) }
                else {
                    Group { if let sender = message.sender { PersonBadge(person: sender, size: 28) } else { Color.clear } }.frame(width: 28, height: 28)
                }
                VStack(alignment: message.mine ? .trailing : .leading, spacing: 3) {
                    if showsName && !message.mine, let sender = message.sender {
                        Text(sender.name).font(.caption2.bold()).foregroundStyle(RoamStyle.red).padding(.horizontal, 6)
                    }
                    Text(message.body).font(.body).foregroundStyle(message.mine ? .white : .black)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .roamGlass(20, tint: message.mine ? RoamStyle.red : nil)
                        .opacity(message.id.hasPrefix("pending-") ? 0.6 : 1).textSelection(.enabled)
                }
                if !message.mine { Spacer(minLength: 60) }
            }.padding(.top, showsName ? 6 : 0)
        }
    }
    private var planBar: some View {
        HStack(spacing: 10) {
            RoamAvatar(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(detail?.plan == nil ? "Pronti a decidere?" : "Il piano è pronto").font(.caption.bold()).foregroundStyle(.black)
                Text(hasDiscussion ? "\(voices) di \(members.count) hanno detto la loro" : "Prima discutete nel gruppo").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Button { confirmPlan = true } label: {
                Label(detail?.plan == nil ? "Pianifica" : "Aggiorna", systemImage: "sparkles").font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(height: 34).roamGlassCapsule(interactive: true, tint: hasDiscussion && !planning ? RoamStyle.red : RoamStyle.red.opacity(0.4))
            }.buttonStyle(DiscoveryPressStyle()).disabled(!hasDiscussion || planning).accessibilityHint("ROAM legge la discussione e scrive il piano")
        }.padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 6).roamGlass(24).padding(.horizontal, 12).padding(.top, 6)
    }
    private func load() async {
        do {
            let fresh: GroupDetail = try await store.request("/groups/\(group.id)")
            if fresh.messages.map(\.id) != messages.map(\.id) || fresh.members.count != members.count {
                withAnimation(.easeOut(duration: 0.2)) { detail = fresh }
            }
            if let i = store.groups.firstIndex(where: { $0.id == group.id }) { store.groups[i].unread = 0 }
        } catch let error as NSError where error.code == 404 { dismiss() }
        catch {}
    }
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""; sending = true; failure = nil; defer { sending = false }
        do {
            let _: GroupMessage = try await store.request("/groups/\(group.id)/messages", method: "POST", body: JSONSerialization.data(withJSONObject: ["body": text]))
            await load()
        } catch { draft = text; failure = "Messaggio non inviato. Riprova." }
    }
    private func plan() async {
        withAnimation { planning = true }; failure = nil
        defer { withAnimation { planning = false } }
        do {
            let _: GroupMessage = try await store.request("/groups/\(group.id)/plan", method: "POST")
            await load(); await store.loadGroups()
        } catch { failure = error.localizedDescription }
    }
    private func leave() async {
        guard let url = URL(string: store.apiURL + "/groups/\(group.id)/leave") else { return }
        _ = try? await URLSession.shared.data(for: store.authorized(url, method: "POST"))
        await store.loadGroups(); dismiss()
    }
}

struct AddGroupMembersView: View {
    let groupID: String
    let current: Set<String>
    let onAdded: (GroupDetail) -> Void
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var people: [Person] = []
    @State private var picked = Set<String>()
    @State private var saving = false
    var body: some View {
        NavigationStack {
            List {
                ForEach(people.filter { $0.has_account && !$0.mine && !current.contains($0.key) }) { person in
                    Button { if picked.contains(person.key) { picked.remove(person.key) } else { picked.insert(person.key) } } label: {
                        HStack { PersonPickerRow(person: person); Image(systemName: picked.contains(person.key) ? "checkmark.circle.fill" : "plus.circle").font(.title3).foregroundStyle(RoamStyle.red) }
                    }.buttonStyle(.plain).roamGlassRow()
                }
            }
            .listStyle(.plain).roamGlassForm()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca viaggiatori")
            .navigationTitle("Invita nel gruppo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await add() } } label: { if saving { ProgressView() } else { Text("Aggiungi").bold() } }.disabled(picked.isEmpty || saving)
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 300))
                if let found = try? await store.searchPeople(query), !Task.isCancelled { people = found }
            }
        }
    }
    private func add() async {
        saving = true; defer { saving = false }
        if let updated: GroupDetail = try? await store.request("/groups/\(groupID)/members", method: "POST", body: JSONSerialization.data(withJSONObject: ["members": Array(picked)])) {
            onAdded(updated); dismiss()
        }
    }
}

// MARK: The plan

/// ROAM's plan: summary, a day picker, the route on a map and every stop openable in Maps.
struct GroupPlanCard: View {
    let plan: TripPlan
    let created: String
    @State private var day = 0
    @State private var openedPlace: Place?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var current: PlanDay? { plan.days.indices.contains(day) ? plan.days[day] : plan.days.first }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoamAvatar(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Il piano di ROAM").font(.headline).foregroundStyle(.black)
                    Text([plan.destination, plan.start_date.flatMap { s in plan.end_date.map { TripDates.range(s, $0) } }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up").font(.subheadline.bold()).foregroundStyle(RoamStyle.red).frame(width: 36, height: 36).roamGlassCircle(interactive: true) }
                    .accessibilityLabel("Condividi il piano")
            }
            Text(plan.summary).font(.subheadline).foregroundStyle(.black.opacity(0.85)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            if plan.days.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(plan.days.indices, id: \.self) { i in
                            Button { withAnimation(reduceMotion ? nil : .spring(response: 0.3)) { day = i } } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Giorno \(i + 1)").font(.caption.bold())
                                    Text(plan.days[i].title).font(.caption2).lineLimit(1)
                                }.foregroundStyle(day == i ? .white : .black).padding(.horizontal, 12).padding(.vertical, 7)
                                    .roamGlassCapsule(interactive: true, tint: day == i ? RoamStyle.red : nil)
                            }.buttonStyle(.plain).accessibilityAddTraits(day == i ? .isSelected : [])
                        }
                    }
                }
            }
            if let current {
                if plan.days.count == 1 { Text(current.title).font(.subheadline.bold()).foregroundStyle(RoamStyle.red) }
                Map(initialPosition: .automatic) {
                    if current.stops.count > 1 {
                        MapPolyline(coordinates: current.stops.map(\.coordinate)).stroke(RoamStyle.red, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 8]))
                    }
                    ForEach(Array(current.stops.enumerated()), id: \.element.id) { index, stop in
                        Annotation(stop.name, coordinate: stop.coordinate) {
                            Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white).frame(width: 30, height: 30).roamGlassCircle(tint: RoamStyle.red)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                .frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).id(day)
                VStack(spacing: 8) {
                    ForEach(Array(current.stops.enumerated()), id: \.element.id) { index, stop in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").font(.subheadline.bold()).foregroundStyle(RoamStyle.red).frame(width: 32, height: 32).roamGlassCircle()
                            Button { openedPlace = stop.place } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop.name).font(.subheadline.bold()).foregroundStyle(.black).multilineTextAlignment(.leading)
                                    Text(stop.note.isEmpty ? stop.category : "\(stop.category) · \(stop.note)").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                            Button { stop.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]) } label: {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill").font(.subheadline).foregroundStyle(RoamStyle.red).frame(width: 34, height: 34).roamGlassCircle(interactive: true)
                            }.accessibilityLabel("Indicazioni per \(stop.name)")
                        }.padding(10).roamGlass(18)
                    }
                }
                Button { MKMapItem.openMaps(with: current.stops.map(\.mapItem)) } label: {
                    Label("Apri le tappe in Mappe", systemImage: "map").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 44).roamGlassCapsule(interactive: true, tint: RoamStyle.red)
                }.buttonStyle(DiscoveryPressStyle())
            }
            if plan.mode == "local" {
                Text("Piano generato senza modello: discutete e chiedete di aggiornarlo quando l’assistente è disponibile.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14).roamGlass(28)
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(RoamStyle.red.opacity(0.3), lineWidth: 1))
        .sheet(item: $openedPlace) { PlaceSheet(place: $0) }
    }
    private var shareText: String {
        ([plan.summary] + plan.days.enumerated().map { i, d in "Giorno \(i + 1) — \(d.title): " + d.stops.map(\.name).joined(separator: " → ") }).joined(separator: "\n\n")
    }
}
