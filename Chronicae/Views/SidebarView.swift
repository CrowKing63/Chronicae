import SwiftUI
import Observation

struct SidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        List(selection: $appState.selectedSection) {
            Section("Chronicae") {
                ForEach(AppState.Section.allCases) { section in
                    Label(section.rawValue, systemImage: icon(for: section))
                        .tag(section)
                }
            }

            if let project = appState.activeProject {
                Section("현재 프로젝트") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        Text("노트 \(project.noteCount)개")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let lastIndexedAt = project.lastIndexedAt {
                            Text(lastIndexedAt, style: .relative)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Chronicae")
        .listStyle(.sidebar)
    }

    private func icon(for section: AppState.Section) -> String {
        switch section {
        case .dashboard: return "speedometer"
        case .storage: return "internaldrive"
        case .versions: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}
