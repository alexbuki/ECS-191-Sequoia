import SwiftUI
import DesignSystem
import SequoiaCore

/// What the name means, told briefly and respectfully.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                HStack {
                    Spacer()
                    TreeView(stage: .grownSequoia).frame(height: 140)
                    Spacer()
                }
                .accessibilityHidden(true)

                Text("Sequoia")
                    .font(Typography.wordHero)

                section(title: "Sequoyah") {
                    Text("Sequoyah (c. 1770–1843) was a Cherokee silversmith and scholar who spent years creating a syllabary for the Cherokee language, completing it around 1821. It was simple enough to learn in days, and within a few years a large share of the Cherokee Nation could read and write. Cherokee communities still use his syllabary today.")
                    Text("His work is a lasting reminder of how much good can come from words.")
                }

                section(title: "The sequoia tree") {
                    Text("Giant sequoias grow slowly and steadily for thousands of years, adding a ring of growth each year. The tree's name is widely said to honor Sequoyah, though the botanist who named it never recorded why.")
                    Text("Sequoia works the same way: one word a day, a little growth each time, adding up to something lasting.")
                }

                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Palette.soilSecondary)
            }
            .padding(Theme.Spacing.l)
        }
        .sequoiaScreen()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Theme.Palette.canopy)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(Typography.body)
                .foregroundStyle(Theme.Palette.soil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview { NavigationStack { AboutView() } }
#Preview("Dark") { NavigationStack { AboutView() }.preferredColorScheme(.dark) }
