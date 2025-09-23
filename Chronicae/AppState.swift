import Foundation
import Observation

@Observable final class AppState {
    enum Section: String, CaseIterable, Identifiable {
        case dashboard = "대시보드"
        case storage = "저장소 관리"
        case versions = "버전 기록"
        case settings = "설정"

        var id: String { rawValue }
    }

    var selectedSection: Section? = .dashboard
    var serverStatus: ServerStatus = .stopped
    var activeProject: ProjectSummary? = nil
    var projects: [ProjectSummary] = []
    var lastUpdated: Date = .now
}

struct ProjectSummary: Identifiable, Hashable {
    let id: UUID
    var name: String
    var noteCount: Int
    var lastIndexedAt: Date?
}
