import SwiftUI
import StoreKit
import UniformTypeIdentifiers

struct LecturesListView: View {
    @AppStorage("hasConfirmedAIProcessingConsent") private var hasConfirmedAIProcessingConsent = false
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State var viewModel: LecturesListViewModel
    let paywallPresentationModel: PaywallPresentationModel
    let repository: LectureRepository
    let authService: FirebaseAuthService?
    let processingService: FirebaseLectureProcessingService?
    let userProfileService: FirebaseUserProfileService?
    let analyticsService: AppAnalyticsService?
    let crashReportingService: CrashReportingService?
    @State private var activeFileImport: LocalFileImport = .importAudio
    @State private var isFileImporterPresented = false
    @State private var pendingLocalConsentAction: LocalFileImport?

    var body: some View {
        @Bindable var viewModel = viewModel
        let displayedLectures = viewModel.displayedLectures

        NavigationStack {
            List {
                if !viewModel.folders.isEmpty {
                    FolderFilterChipsView(
                        folders: viewModel.folders,
                        selectedFolderID: $viewModel.selectedFolderID
                    )
                    .homeListRowStyle()
                }

                if viewModel.showsInitialLoadingIndicator && !viewModel.hasCompletedInitialLoad {
                    LoadingLecturesPlaceholderView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .homeListRowStyle()
                } else if viewModel.lectures.isEmpty && viewModel.hasCompletedInitialLoad {
                    EmptyLecturesPlaceholderView {
                        presentAudioImportFlow()
                    } onImportText: {
                        viewModel.requestFlow(.importText, hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent)
                    } onImportYouTube: {
                        viewModel.requestFlow(.importYouTube, hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent)
                    } onImportPDF: {
                        presentPDFImportFlow()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .homeListRowStyle()
                } else if viewModel.filteredLectures.isEmpty, viewModel.hasActiveSearchQuery {
                    Group {
                        if viewModel.isSearching {
                            ProgressView()
                        } else {
                            EmptySearchResultsPlaceholderView(query: viewModel.searchText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .homeListRowStyle()
                } else if viewModel.filteredLectures.isEmpty, viewModel.selectedFolderID != nil {
                    EmptyFolderPlaceholderView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .homeListRowStyle()
                } else {
                    ForEach(displayedLectures) { lecture in
                        LectureRowView(
                            lecture: lecture,
                            onOpen: {
                                viewModel.openLecture(lecture)
                            },
                            onMore: {
                                viewModel.presentActionSheet(for: lecture.id)
                            }
                        )
                        .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 12))
                        .listRowBackground(Color.clear)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 52 }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash") {
                                viewModel.requestDelete(lecture)
                            }
                            .tint(.red)

                            if lecture.folderID == nil {
                                Button("Add to folder", systemImage: "folder") {
                                    viewModel.presentFolderPicker(for: lecture.id)
                                }
                                .tint(.indigo)
                            } else {
                                Button("Remove from folder", systemImage: "folder.badge.minus") {
                                    removeLectureFromFolder(lecture.id)
                                }
                                .tint(.orange)
                            }
                        }
                        .contextMenu {
                            if lecture.status == .failed, processingService != nil {
                                Button("Retry", systemImage: "arrow.clockwise") {
                                    viewModel.retryProcessing(lecture.id)
                                }
                            }

                            Button("Edit title", systemImage: "pencil") {
                                viewModel.requestRename(lecture)
                            }

                            if lecture.folderID == nil {
                                Button("Add to folder", systemImage: "folder") {
                                    viewModel.presentFolderPicker(for: lecture.id)
                                }
                            } else {
                                Button("Remove from folder", systemImage: "folder.badge.minus") {
                                    removeLectureFromFolder(lecture.id)
                                }
                            }

                            Divider()

                            Button("Delete", systemImage: "trash", role: .destructive) {
                                viewModel.requestDelete(lecture)
                            }
                        }
                        .onAppear {
                            viewModel.loadMoreLecturesIfNeeded(currentLectureID: lecture.id)
                        }
                    }

                    if viewModel.hasMoreLecturesToDisplay {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .homeListRowStyle()
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 100, for: .scrollContent)
            .background(AppColor.canvas)
            .navigationTitle("Recordings")
            .searchable(
                text: $viewModel.searchText,
                isPresented: $viewModel.isSearchPresented,
                prompt: Text("Search lectures")
            )
            .onChange(of: viewModel.isSearchPresented) { _, isPresented in
                if !isPresented {
                    viewModel.dismissSearch()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        FoldersScreen(viewModel: viewModel)
                    } label: {
                        Label("Folders", systemImage: "folder")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HomeImportMenu {
                        presentAudioImportFlow()
                    } onImportText: {
                        viewModel.requestFlow(.importText, hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent)
                    } onImportYouTube: {
                        viewModel.requestFlow(.importYouTube, hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent)
                    } onImportPDF: {
                        presentPDFImportFlow()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            authService: authService,
                            userProfileService: userProfileService,
                            analyticsService: analyticsService,
                            crashReportingService: crashReportingService
                        )
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationDestination(item: $viewModel.selectedLecture) { lecture in
                LectureDetailView(
                    lecture: lecture,
                    repository: repository,
                    processingService: processingService,
                    analyticsService: analyticsService,
                    crashReportingService: crashReportingService,
                    onLectureUpdated: { updatedLecture in
                        viewModel.handleLectureUpdated(updatedLecture)
                    },
                    onLectureDeleted: { lectureID in
                        let result = await viewModel.deleteLecture(lectureID)

                        switch result {
                        case .deleted:
                            await MainActor.run {
                                viewModel.handleLectureDeletedNavigation(lectureID)
                            }
                            return nil
                        case .rejected(let message):
                            return message
                        }
                    },
                    onUpgradeRequested: {
                        Task {
                            await paywallPresentationModel.presentDefaultPaywall()
                        }
                    }
                )
            }
            .homeRecordControl(
                isHidden: viewModel.activeSheet != nil || viewModel.recorderViewModel != nil || viewModel.isAIConsentPresented
            ) {
                Task {
                    await viewModel.requestRecordingFlow(
                        hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent
                    )
                }
            }
            .overlay {
                if viewModel.recorderViewModel != nil {
                    Button {
                        viewModel.recorderViewModel = nil
                    } label: {
                        AppColor.overlayScrim
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                if viewModel.isAIConsentPresented {
                    Button {
                        viewModel.dismissAIConsent()
                    } label: {
                        AppColor.overlayScrim
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let recorderViewModel = viewModel.recorderViewModel {
                    MiniRecorderSheetView(
                        viewModel: recorderViewModel,
                        onSave: { recording in
                            Task {
                                await viewModel.saveRecordingDraft(recording)
                            }
                        }
                    ) {
                        viewModel.recorderViewModel = nil
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if viewModel.isAIConsentPresented {
                    AIProcessingConsentCard(
                        onCancel: {
                            pendingLocalConsentAction = nil
                            viewModel.dismissAIConsent()
                        },
                        onContinue: {
                            hasConfirmedAIProcessingConsent = true
                            if let pendingLocalConsentAction {
                                self.pendingLocalConsentAction = nil
                                viewModel.dismissAIConsent()

                                switch pendingLocalConsentAction {
                                case .importAudio:
                                    presentFileImport(.importAudio)
                                case .importPDF:
                                    presentFileImport(.importPDF)
                                }
                            } else {
                                viewModel.continuePendingConsentAction()
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if let toastPresentation = viewModel.toastPresentation {
                    ToastBannerView(toastPresentation: toastPresentation)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.toastPresentation != nil)
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: viewModel.recorderViewModel != nil)
            .sensoryFeedback(.success, trigger: viewModel.removalFeedbackToken)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.importFeedbackToken)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.importLimitFeedbackToken)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.processingStartFeedbackToken)
            .sheet(item: $viewModel.activeSheet) { sheet in
                switch sheet {
                case .actions(let lectureID):
                    if let lecture = viewModel.lecture(withID: lectureID) {
                        RecordingActionsSheet(
                            lecture: lecture,
                            onAddToFolder: {
                                viewModel.presentFolderPicker(for: lectureID)
                            },
                            onRemoveFromFolder: lecture.folderID == nil ? nil : {
                                removeLectureFromFolder(lectureID)
                            },
                            onEditTitle: {
                                viewModel.requestRename(lecture)
                            },
                            onShare: {},
                            onDelete: {
                                viewModel.closeActiveSheet()
                                Task {
                                    let result = await viewModel.deleteLecture(lectureID)
                                    await MainActor.run {
                                        switch result {
                                        case .deleted:
                                            viewModel.removalFeedbackToken += 1
                                        case .rejected(let message):
                                            viewModel.presentErrorAlert(message)
                                        }
                                    }
                                }
                            }
                        )
                        .presentationDetents([.height(lecture.folderID == nil ? 290 : 340), .fraction(0.52)])
                    }
                case .folderPicker(let lectureID):
                    if let lecture = viewModel.lecture(withID: lectureID) {
                        FolderSelectionSheet(
                            lecture: lecture,
                            folders: viewModel.folders,
                            selectedFolderID: lecture.folderID,
                            onCreateFolder: { folderName in
                                viewModel.createFolder(named: folderName)
                            },
                            onSelectFolder: { folderID in
                                viewModel.addLecture(lectureID, toFolder: folderID)
                            },
                            onClose: {
                                viewModel.closeActiveSheet()
                            }
                        )
                        .presentationDetents([.fraction(0.52), .large])
                    }
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: activeFileImport.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                Task {
                    switch activeFileImport {
                    case .importAudio:
                        await viewModel.handleAudioImportResult(result)
                    case .importPDF:
                        await viewModel.handlePDFImportResult(result)
                    }
                }
            }
            .fullScreenCover(
                isPresented: $viewModel.isTextImportSheetPresented,
                onDismiss: {
                    viewModel.finishTextImportDismissal()
                }
            ) {
                TextImportSheetView(
                    onClose: {
                        viewModel.dismissTextImportSheet()
                    },
                    onSubmit: { text in
                        await viewModel.submitTextImport(text)
                    }
                )
            }
            .fullScreenCover(
                isPresented: $viewModel.isYouTubeImportSheetPresented,
                onDismiss: {
                    viewModel.finishYouTubeImportDismissal()

                    if viewModel.consumeYouTubeImportPaywallRequest() {
                        Task {
                            await paywallPresentationModel.presentYouTubeImportPaywall()
                        }
                    }
                }
            ) {
                YouTubeImportSheetView(
                    onClose: {
                        viewModel.dismissYouTubeImportSheet()
                    },
                    onSubmit: { urlString in
                        await viewModel.submitYouTubeImport(
                            urlString,
                            plan: subscriptionManager.currentPlan
                        )
                    }
                )
            }
            .sheet(
                item: $viewModel.importLimitSheetContent,
                onDismiss: {
                    viewModel.dismissImportLimitSheet()
                }
            ) { content in
                ImportLimitSheetView(
                    title: content.title,
                    message: content.message,
                    upgradeTitle: content.upgradeTitle,
                    upgradeMessage: content.upgradeMessage,
                    onViewPlans: {
                        viewModel.dismissImportLimitSheet()
                        Task {
                            await paywallPresentationModel.presentDefaultPaywall()
                        }
                    }
                )
                .presentationDetents([.height(ImportLimitSheetView.estimatedSheetHeight)])
                .presentationDragIndicator(.visible)
            }
            .alert("Import", isPresented: $viewModel.isImportAlertPresented) {
                Button("OK") {
                    viewModel.dismissImportAlert()
                }
            } message: {
                Text(viewModel.importAlertMessage)
            }
            .alert("Error", isPresented: $viewModel.isErrorAlertPresented) {
                Button("OK") {
                    viewModel.dismissErrorAlert()
                }
            } message: {
                Text(viewModel.errorAlertMessage)
            }
            .alert(
                "Edit Title",
                isPresented: Binding(
                    get: { viewModel.isRenameAlertPresented },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.dismissRenameAlert()
                        }
                    }
                )
            ) {
                TextField("Lecture title", text: $viewModel.draftTitle)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    viewModel.saveRenamedLecture()
                }
                .disabled(
                    viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSavingTitle
                )
            } message: {
                Text("Update the lecture title.")
            }
            .alert(
                "Delete Lecture?",
                isPresented: Binding(
                    get: { viewModel.pendingDeletionLecture != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.dismissDeletionAlert()
                        }
                    }
                ),
                presenting: viewModel.pendingDeletionLecture
            ) { _ in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.confirmPendingDeletion()
                    }
                }
            } message: { lecture in
                Text("Delete \"\(lecture.displayTitle)\"? This action cannot be undone.")
            }
            .task {
                await viewModel.load()
            }
            .onChange(of: viewModel.reviewRequestToken, initial: false) { oldValue, newValue in
                guard newValue > oldValue else {
                    return
                }
                requestReview()
            }
        }
    }

    private func presentAudioImportFlow() {
        guard processingService != nil else {
            presentFileImport(.importAudio)
            return
        }

        if hasConfirmedAIProcessingConsent {
            presentFileImport(.importAudio)
        } else {
            pendingLocalConsentAction = .importAudio
            viewModel.isAIConsentPresented = true
        }
    }

    private func presentPDFImportFlow() {
        guard processingService != nil else {
            presentFileImport(.importPDF)
            return
        }

        if hasConfirmedAIProcessingConsent {
            presentFileImport(.importPDF)
        } else {
            pendingLocalConsentAction = .importPDF
            viewModel.isAIConsentPresented = true
        }
    }

    private func presentFileImport(_ fileImport: LocalFileImport) {
        let sourceType = switch fileImport {
        case .importAudio:
            "audio"
        case .importPDF:
            "pdf"
        }
        analyticsService?.track(
            .contentCreateStarted(
                sourceType: sourceType,
                entryPoint: "file_importer",
                plan: userProfileService?.currentProfile?.plan
            )
        )
        activeFileImport = fileImport
        isFileImporterPresented = true
    }

    /// Takes a lecture out of its folder from any entry point (row swipe, context menu
    /// or actions sheet) and confirms it with haptics and a toast.
    private func removeLectureFromFolder(_ lectureID: Lecture.ID) {
        let folderName = viewModel.removeLectureFromFolder(lectureID)
        viewModel.closeActiveSheet()
        viewModel.removalFeedbackToken += 1
        viewModel.showToast(
            folderName.map { String(appLocalized: "Removed from \($0).") } ?? String(appLocalized: "Removed from folder.")
        )
    }
}

private extension View {
    /// Full-width list row without a separator or background, for banners, chips and placeholders.
    func homeListRowStyle() -> some View {
        listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private struct ToastBannerView: View {
    let toastPresentation: LecturesListViewModel.ToastPresentation

    var body: some View {
        Group {
            switch toastPresentation.content {
            case .localized(let resource):
                Text(resource)
            case .custom(let string):
                Text(verbatim: string)
            }
        }
        .foregroundStyle(AppColor.onInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColor.ink.opacity(0.88))
        .clipShape(.rect(cornerRadius: 14))
        .shadow(color: AppColor.shadow, radius: 10, y: 4)
    }
}


private struct LoadingLecturesPlaceholderView: View {
    var body: some View {
        ProgressView("Loading recordings")
    }
}

private struct EmptyFolderPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Text("No recordings in this folder")
        } description: {
            Text("Use the menu button on a recording to move it into this folder.")
        }
    }
}

private struct EmptySearchResultsPlaceholderView: View {
    let query: String

    var body: some View {
        ContentUnavailableView {
            Text("Nothing found")
        } description: {
            Text("No recordings match \"\(query)\".")
        }
    }
}

private enum LocalFileImport {
    case importAudio
    case importPDF

    var allowedContentTypes: [UTType] {
        switch self {
        case .importAudio:
            [.audio]
        case .importPDF:
            [.pdf]
        }
    }
}

#Preview {
    LecturesListPreviewCanvas()
}

private struct LecturesListPreviewCanvas: View {
    private let lectures = MockLectures.makeLectures()

    var body: some View {
        NavigationStack {
            List {
                ForEach(lectures) { lecture in
                    LectureRowView(lecture: lecture, onOpen: {}, onMore: {})
                        .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 12))
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColor.canvas)
            .navigationTitle("Recordings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HomeImportMenu {} onImportText: {} onImportYouTube: {} onImportPDF: {}
                }
            }
        }
    }
}
