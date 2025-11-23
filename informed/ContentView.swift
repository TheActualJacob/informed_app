import SwiftUI
internal import Combine
import SafariServices

// MARK: - 1. DESIGN SYSTEM & EXTENSIONS

extension Color {
    // Primary Palette
    static let brandTeal = Color(red: 0.0, green: 0.75, blue: 0.85)
    static let brandBlue = Color(red: 0.15, green: 0.35, blue: 0.95)
    
    // Backgrounds
    static let backgroundLight = Color(red: 0.97, green: 0.98, blue: 1.0) // Soft Cloud
    static let cardShadow = Color.black.opacity(0.06)
    
    // Semantics
    static let brandGreen = Color(red: 0.2, green: 0.75, blue: 0.45)
    static let brandYellow = Color(red: 0.98, green: 0.75, blue: 0.15)
    static let brandRed = Color(red: 0.95, green: 0.3, blue: 0.3)
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - 2. MODELS

enum CredibilityLevel: String {
    case high = "Verified"
    case medium = "Debated"
    case low = "Misleading"

    var color: Color {
        switch self {
        case .high: return Color.brandGreen
        case .medium: return Color.brandYellow
        case .low: return Color.brandRed
        }
    }

    var icon: String {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "xmark.octagon.fill"
        }
    }
}

struct FactCheck: Codable {
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let summary: String
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case claim, verdict, explanation, summary, sources
        case claimAccuracyRating = "claim_accuracy_rating"
    }
}

struct FactCheckItem: Identifiable {
    let id = UUID()
    let sourceName: String
    let sourceIcon: String
    let timeAgo: String
    let title: String
    let summary: String
    let thumbnailURL: URL?
    let credibilityScore: Double // 0.0 to 1.0
    let sources: String
    let verdict: String
    let factCheck: FactCheck

    // Detailed data for the DetailView
    var detailedAnalysis: String {
        return factCheck.explanation
    }

    var credibilityLevel: CredibilityLevel {
        if credibilityScore >= 0.8 { return .high }
        if credibilityScore >= 0.5 { return .medium }
        return .low
    }
}

// MARK: - 3. VIEW MODEL

class HomeViewModel: ObservableObject {
    @Published var items: [FactCheckItem] = []
    @Published var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                checkIfLink(searchText)
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init() {
        loadData()
    }
    
    private func checkIfLink(_ text: String) {
        // Check if the text is a valid URL
        guard let url = URL(string: text),
              url.scheme != nil,
              url.host != nil else {
            return
        }
        
        // If it's a valid URL, send the fact check request
        Task {
            await performFactCheck(for: text)
        }
    }
    
    @MainActor
    func performFactCheck(for link: String) async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // Create the fact check request with a user ID
            // You can replace "default-user" with an actual user ID from your app
            let request = FactCheckRequest(link: link, userId: "default-user")
            
            // Send the request
            let data = try await sendFactCheck(request)
            
            // Decode the response
            let factCheck = try JSONDecoder().decode(FactCheck.self, from: data)
            
            // Create a new FactCheckItem from the response
            let newItem = FactCheckItem(
                sourceName: "Fact Check API",
                sourceIcon: "checkmark.seal.fill",
                timeAgo: "Just now",
                title: factCheck.claim,
                summary: factCheck.summary,
                thumbnailURL: nil,
                credibilityScore: calculateCredibilityScore(from: factCheck.claimAccuracyRating),
                sources: factCheck.sources.joined(separator: ", "),
                verdict: factCheck.verdict,
                factCheck: factCheck
            )
            
            // Add the new item to the top of the list
            self.items.insert(newItem, at: 0)
            
            // Clear the search text
            self.searchText = ""
            
        } catch {
            self.errorMessage = "Failed to check fact: \(error.localizedDescription)"
            print("Error performing fact check: \(error)")
        }
        
        self.isLoading = false
    }
    
    private func calculateCredibilityScore(from rating: String) -> Double {
        // Extract percentage from rating string like "100%" or "5%"
        let numericString = rating.replacingOccurrences(of: "%", with: "")
        if let percentage = Double(numericString) {
            return percentage / 100.0
        }
        return 0.5 // Default to 50% if parsing fails
    }
    
    func loadData() {
        self.isLoading = true

        // Mock Network Delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.items = [
                // NYC Election Fact Check
                FactCheckItem(
                    sourceName: "News Aggregator",
                    sourceIcon: "newspaper.fill",
                    timeAgo: "1h ago",
                    title: "NYC 2025 Mayoral Election Voter Turnout",
                    summary: "More people voted in New York City's election this year than they have in 50 years.",
                    thumbnailURL: URL(string: "https://images.unsplash.com/photo-1554687589-f6b201f55d95?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                    credibilityScore: 1.0,
                    sources: "News Aggregator",
                    verdict: "True",
                    factCheck: FactCheck(
                        claim: "More people voted in New York City's election this year than they have in 50 years.",
                        verdict: "True",
                        claimAccuracyRating: "100%",
                        explanation: "The claim states that the 2025 New York City election saw the highest voter turnout in 50 years. According to multiple news sources and the New York City Board of Elections, the 2025 mayoral election had the largest voter turnout in over 50 years, with more than 2 million New Yorkers casting ballots. The last time a mayoral race had over 2 million voters was in 1969. This confirms the claim's accuracy.",
                        summary: "The 2025 New York City mayoral election had the highest voter turnout in over 50 years, with over 2 million voters casting ballots, making the claim true.",
                        sources: [
                            "https://www.cityandstateny.com/politics/2025/11/5-takeaways-2025-nyc-election-turnout/409413/",
                            "https://www.nbcnewyork.com/news/politics/nyc-voter-turnout-breaking-records/6414233/",
                            "https://www.nytimes.com/2025/11/04/nyregion/nyc-mayor-election-turnout.html",
                            "https://www.pbs.org/newshour/politics/democrat-zohran-mamdani-wins-new-york-city-mayors-race"
                        ]
                    )
                ),
                // AI Chip Fact Check
                FactCheckItem(
                    sourceName: "TechCrunch",
                    sourceIcon: "network",
                    timeAgo: "2h ago",
                    title: "Does the new AI Chip actually use human neurons?",
                    summary: "Viral claims suggest the new Z-90 chip uses biological components. Our analysis confirms it uses silicon-based neuromorphic architecture.",
                    thumbnailURL: URL(string: "https://images.unsplash.com/photo-1555255707-c07966088b7b?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                    credibilityScore: 0.95,
                    sources: "TechCrunch",
                    verdict: "False",
                    factCheck: FactCheck(
                        claim: "The new Z-90 AI chip incorporates actual human neurons into its architecture.",
                        verdict: "False",
                        claimAccuracyRating: "5%",
                        explanation: "Extensive technical documentation and manufacturer specifications confirm that the Z-90 chip uses exclusively silicon-based components with neuromorphic architecture designed to mimic neural behavior. No biological components are used. The claim appears to stem from misunderstandings about neuromorphic engineering, which aims to replicate aspects of biological neural networks using electronic circuits, not actual biological tissue.",
                        summary: "The Z-90 chip uses advanced silicon-based neuromorphic architecture to simulate neural behavior, but does not incorporate actual human neurons or any biological components.",
                        sources: [
                            "https://tech-manufacturer.com/z90-technical-specs.pdf",
                            "https://journalofneurotechnology.org/z90-analysis-2025",
                            "https://www.techcrunch.com/2025/10/15/ai-chip-breakdown/",
                            "https://www.electronicnews.com/z90-architecture-review"
                        ]
                    )
                ),
                // Salt Water Health Claim
                FactCheckItem(
                    sourceName: "Health Watch",
                    sourceIcon: "heart.fill",
                    timeAgo: "5h ago",
                    title: "Can drinking salt water cure insomnia?",
                    summary: "A viral social media video claims salt water aids sleep. Medical experts warn of serious health risks.",
                    thumbnailURL: URL(string: "https://images.unsplash.com/photo-1515871204537-49a5e85aee65?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                    credibilityScore: 0.15,
                    sources: "Health Watch",
                    verdict: "False",
                    factCheck: FactCheck(
                        claim: "Drinking salt water can effectively treat insomnia and improve sleep quality.",
                        verdict: "False",
                        claimAccuracyRating: "2%",
                        explanation: "Medical research and the American Sleep Association explicitly refute this claim. Consuming salt water can cause dehydration, electrolyte imbalances, and elevated blood pressure - all of which worsen sleep quality. The trend appears to originate from social media influencers without medical backgrounds. Legitimate sleep treatments include cognitive behavioral therapy, consistent sleep schedules, and in some cases, FDA-approved medications prescribed by healthcare professionals.",
                        summary: "Salt water consumption does not treat insomnia and may cause serious health complications including dehydration and elevated blood pressure.",
                        sources: [
                            "https://www.sleepfoundation.org/sleep-hygiene",
                            "https://www.mayoclinic.org/healthy-lifestyle/adult-health/in-depth/sleep/art-20048379",
                            "https://www.aasm.org/public/resources/sleeptips",
                            "https://pubmed.ncbi.nlm.nih.gov/salt-water-health-effects"
                        ]
                    )
                ),
                // Mars Colony Timeline
                FactCheckItem(
                    sourceName: "Space News",
                    sourceIcon: "globe.americas.fill",
                    timeAgo: "1d ago",
                    title: "Mars colony timeline shifted to 2030",
                    summary: "Conflicting statements about Mars colony plans. Official documents suggest 2035+ is more realistic.",
                    thumbnailURL: URL(string: "https://images.unsplash.com/photo-1614728853975-69c960c72abc?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                    credibilityScore: 0.55,
                    sources: "Space News",
                    verdict: "Mixed",
                    factCheck: FactCheck(
                        claim: "A manned Mars colony will be established by 2030.",
                        verdict: "Mixed",
                        claimAccuracyRating: "35%",
                        explanation: "While some space agency officials have made optimistic public statements about 2030-2035 timelines, internal technical documents and engineering assessments indicate significant obstacles. Life support systems, landing technology, and resource extraction methods still require substantial development. Most peer-reviewed analyses suggest the first permanent settlements are more likely between 2035-2050. The mixed verdict reflects ambitious goals versus engineering realities.",
                        summary: "Current technical roadmaps suggest permanent Mars settlements are 10-20 years away, making 2030 optimistic but not impossible with unprecedented funding and breakthroughs.",
                        sources: [
                            "https://www.nasa.gov/artemis/mars-exploration-program/",
                            "https://spacetechnologyreview.com/mars-timeline-analysis-2025",
                            "https://www.spacenewsjournal.org/mars-colonization-assessment",
                            "https://arxiv.org/abs/space-systems-feasibility"
                        ]
                    )
                ),
                // Vaccine Fact Check
                FactCheckItem(
                    sourceName: "Medical Facts",
                    sourceIcon: "cross.case.fill",
                    timeAgo: "8h ago",
                    title: "Do vaccines contain microchips?",
                    summary: "A persistent false claim about vaccine contents. Scientific evidence clearly refutes this.",
                    thumbnailURL: URL(string: "https://images.unsplash.com/photo-1584308666744-24d5f15714ae?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80"),
                    credibilityScore: 0.98,
                    sources: "Medical Facts",
                    verdict: "False",
                    factCheck: FactCheck(
                        claim: "COVID-19 vaccines contain microchips for surveillance and tracking.",
                        verdict: "False",
                        claimAccuracyRating: "0%",
                        explanation: "This claim is physically impossible. Vaccine syringes use 25-gauge needles (0.5mm diameter), while the smallest commercially available microchips are hundreds of times larger. Vaccine contents are documented and tested by regulatory agencies worldwide. The mRNA and ingredients are publicly available information. Microchips require power sources and wireless transmission capabilities that would be detectable. This misinformation appears designed to discourage vaccination during public health emergencies.",
                        summary: "Vaccines contain documented, publicly available ingredients. No microchips have ever been found in any vaccine batch tested by independent laboratories worldwide.",
                        sources: [
                            "https://www.fda.gov/emergency-preparedness-response/coronavirus-disease-2019-covid-19/covid-19-vaccines",
                            "https://www.who.int/emergencies/diseases/novel-coronavirus-2019/question-and-answers-hub",
                            "https://www.factcheck.org/2021/05/the-facts-on-covid-19-vaccine-ingredients/",
                            "https://sciencemag.org/vaccine-ingredient-transparency"
                        ]
                    )
                )
            ]
            self.isLoading = false
        }
    }
    
    func refresh() {
        items.removeAll()
        loadData()
    }
}

// MARK: - 4. REUSABLE COMPONENTS

func extractDomainName(from urlString: String) -> String {
    guard let url = URL(string: urlString),
          let host = url.host else {
        return urlString
    }

    // Remove www. prefix if present
    var domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

    // Take only the main domain (e.g., "nytimes.com" from "www.nytimes.com")
    let components = domain.split(separator: ".")
    if components.count > 1 {
        domain = components.dropFirst(max(0, components.count - 2)).joined(separator: ".")
    }

    return domain.capitalized
}

struct SearchBarView: View {
    @Binding var text: String
    
    private var isValidURL: Bool {
        guard let url = URL(string: text),
              url.scheme != nil,
              url.host != nil else {
            return false
        }
        return true
    }
    
    var body: some View {
        HStack {
            Image(systemName: isValidURL ? "link.circle.fill" : "magnifyingglass")
                .foregroundColor(isValidURL ? .brandGreen : .brandBlue)
            TextField("Paste a link or search...", text: $text)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isValidURL ? Color.brandGreen : Color.clear, lineWidth: 2)
        )
    }
}

struct DonutChart: View {
    var score: Double
    var color: Color
    
    @State private var animatedScore: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 15)
                .opacity(0.1)
                .foregroundColor(color)
            
            Circle()
                .trim(from: 0.0, to: animatedScore)
                .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
            
            VStack {
                Text("\(Int(score * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("Truth Score")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) {
                animatedScore = CGFloat(score)
            }
        }
    }
}

struct LinkPreviewView: View {
    let item: FactCheckItem
    
    var body: some View {
        HStack(spacing: 0) {
            AsyncImage(url: item.thumbnailURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 90, height: 90)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    // ← REMOVE .fixedSize(horizontal: false, vertical: true)
                Text(item.sourceName)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity) // ← ADD THIS
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}
struct FactResultCard: View {
    let item: FactCheckItem
    // Removed the specific isHovered state that was causing conflicts
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: item.sourceIcon)
                    .foregroundColor(.brandBlue)
                    .padding(8)
                    .background(Color.brandBlue.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text("Verified by AI + Humans")
                        .font(.caption2).fontWeight(.bold).foregroundColor(.gray)
                    Text(item.timeAgo).font(.caption2).foregroundColor(.gray.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            LinkPreviewView(item: item)
            
            Text(item.summary)
                .font(.system(size: 15))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.leading) // Ensures text aligns left
            
            HStack {
                Text("Credibility:")
                    .font(.caption).fontWeight(.bold).foregroundColor(.gray)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: item.credibilityLevel.icon)
                    Text(item.credibilityLevel.rawValue)
                }
                .font(.caption).fontWeight(.bold)
                .foregroundColor(item.credibilityLevel.color)
            }
            
            // Mini Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.1))
                    Capsule().fill(item.credibilityLevel.color)
                        .frame(width: geo.size.width * item.credibilityScore)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.cardShadow, radius: 15, x: 0, y: 8)
    }
}

struct FABView: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2).fontWeight(.bold).foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(colors: [.brandTeal, .brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .shadow(color: .brandBlue.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}

// FACT DETAIL VIEW
struct FactDetailView: View {
    let item: FactCheckItem
    @Environment(\.presentationMode) var presentationMode
    @State private var showSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Hero Section
                ZStack(alignment: .topLeading) {
                    GeometryReader { geo in
                        AsyncImage(url: item.thumbnailURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.brandBlue.opacity(0.1))
                            }
                        }
                        .frame(width: geo.size.width, height: 300)
                        .clipped()
                        .overlay(LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .center))
                    }
                    .frame(height: 300)

                    // Top Bar: Back & Share
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Spacer()

                        Button(action: {
                            let activityVC = UIActivityViewController(activityItems: [item.title, item.summary], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                rootVC.present(activityVC, animated: true)
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                }
            }

            VStack(alignment: .leading, spacing: 24) {

                // Title Area
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(item.credibilityLevel.rawValue, systemImage: item.credibilityLevel.icon)
                            .font(.caption).fontWeight(.bold)
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(item.credibilityLevel.color.opacity(0.1))
                            .foregroundColor(item.credibilityLevel.color)
                            .cornerRadius(8)
                        Spacer()
                        Text(item.timeAgo).font(.caption).foregroundColor(.gray)
                    }

                    Text(item.title)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Animated Chart
                HStack {
                    Spacer()
                    DonutChart(score: item.credibilityScore, color: item.credibilityLevel.color)
                    Spacer()
                }

                // The Claim
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Claim")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(item.factCheck.claim)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)

                // Verdict Badge
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verdict").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                        Text(item.factCheck.verdict)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(item.credibilityLevel.color)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Accuracy Rating").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                        Text(item.factCheck.claimAccuracyRating)
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(item.credibilityLevel.color)
                    }
                }
                .padding(16)
                .background(item.credibilityLevel.color.opacity(0.08))
                .cornerRadius(12)

                // Explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Explanation").font(.headline)
                    Text(item.factCheck.explanation)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.backgroundLight)
                .cornerRadius(12)

                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Summary").font(.headline)
                    Text(item.factCheck.summary)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)

                // Sources
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sources").font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(item.factCheck.sources.indices, id: \.self) { index in
                            Button(action: {
                                if let url = URL(string: item.factCheck.sources[index]) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "link.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.brandBlue)

                                    Text(extractDomainName(from: item.factCheck.sources[index]))
                                        .font(.caption)
                                        .foregroundColor(.brandBlue)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundColor(.brandBlue.opacity(0.6))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.brandBlue.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.backgroundLight)
                .cornerRadius(12)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(30)
            .offset(y: -40)
            .padding(.bottom, 40)
        }
        .edgesIgnoringSafeArea(.top)
        .navigationBarHidden(true)
    }
}
    
    // MARK: - 6. MAIN HOME VIEW
    
struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @State private var showPopup = false // Popup state
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                Color.backgroundLight.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header
                    VStack {
                        SearchBarView(text: $viewModel.searchText)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.backgroundLight)
                    
                    if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView().scaleEffect(1.5)
                            Text("Checking facts...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        VStack(spacing: 0) {
                            // Error message banner
                            if let errorMessage = viewModel.errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.brandYellow)
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button(action: { viewModel.errorMessage = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Color.brandYellow.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            ScrollView {
                                LazyVStack(spacing: 20) {
                                    ForEach(viewModel.items) { item in
                                        
                                        // 👇 THE FIX IS HERE
                                        NavigationLink(destination: FactDetailView(item: item)) {
                                            FactResultCard(item: item)
                                        }
                                        .buttonStyle(PlainButtonStyle()) // Prevents blue text highlight
                                        
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 10)
                                .padding(.bottom, 100)
                            }
                            .refreshable { viewModel.refresh() }
                        }
                    }
                }
                
                FABView{
                    showPopup = true
                }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                
                if showPopup{
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showPopup = false
                        }
                    // Popup content
               VStack(spacing: 20) {
                   Text("This is your popup!")
                       .font(.headline)
                   
                   Button("Close") {
                       showPopup = false
                   }
                   .padding()
                   .background(Color.red)
                   .foregroundColor(.white)
                   .cornerRadius(12)
               }
               .padding()
               .background(Color.white)
               .cornerRadius(20)
               .shadow(radius: 10)
               .frame(maxWidth: 300)
               .transition(.move(edge: .bottom).combined(with: .opacity))
           }
       }
       .animation(.easeInOut, value: showPopup)
       .navigationBarHidden(true)
}

        }
    
}
    
    // MARK: - 7. ROOT CONTENT VIEW
    
    struct ContentView: View {
        init() {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor.white
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        
        var body: some View {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Feed")
                    }
                
                Text("History")
                    .tabItem {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("History")
                    }
                
                Text("Profile")
                    .tabItem {
                        Image(systemName: "person.crop.circle")
                        Text("Profile")
                    }
            }
            .accentColor(.brandBlue)
        }
    }
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
    
    
    
    
    struct SafariView: UIViewControllerRepresentable {
        let url: URL
        func makeUIViewController(context: Context) -> SFSafariViewController {
            return SFSafariViewController(url: url)
        }
        func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    }
