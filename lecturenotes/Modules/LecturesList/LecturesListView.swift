import SwiftUI
import UniformTypeIdentifiers

struct LecturesListView: View {
    private let searchBarReservedHeight: CGFloat = 56
    private let stickySearchTopInset: CGFloat = 70

    @AppStorage("hasConfirmedAIProcessingConsent") private var hasConfirmedAIProcessingConsent = false
    @State var viewModel: LecturesListViewModel
    let paywallPresentationModel: PaywallPresentationModel
    let repository: LectureRepository
    let authService: FirebaseAuthService?
    let processingService: FirebaseLectureProcessingService?
    let userProfileService: FirebaseUserProfileService?
    @State private var activeFileImport: LocalFileImport = .importAudio
    @State private var isFileImporterPresented = false
    @State private var pendingLocalConsentAction: LocalFileImport?
    @State private var currentScrollOffset: CGFloat = 0

    var body: some View {
        @Bindable var viewModel = viewModel
        let showsInlineSearchBar = (viewModel.isSearchPresented || viewModel.hasActiveSearchQuery) && currentScrollOffset < 140
        let showsFloatingSearchBar = viewModel.isSearchAutoPresented || ((viewModel.isSearchPresented || viewModel.hasActiveSearchQuery) && currentScrollOffset >= 140)
        let displayedLectures = viewModel.displayedLectures

        NavigationStack {
            VStack(spacing: 0) {
                HomeHeaderView(
                    authService: authService,
                    userProfileService: userProfileService
                )
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LecturesListScrollOffsetReader()

                        PremiumBannerView(paywallPresentationModel: paywallPresentationModel)

                        QuickActionsStripView {
                            presentAudioImportFlow()
                        } onImportText: {
                            viewModel.requestFlow(.importText, hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent)
                        } onImportYouTube: {
                            viewModel.requestFlow(.importYouTube, hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent)
                        } onImportPDF: {
                            presentPDFImportFlow()
                        }

                        RecordingsSectionHeaderView(
                            foldersDestination: FoldersScreen(viewModel: viewModel),
                            showsFoldersNavigation: true,
                            onSearchTap: {
                                viewModel.presentSearch()
                            }
                        )

                        if showsInlineSearchBar {
                            LecturesSearchBarView(
                                text: $viewModel.searchText,
                                isSearching: viewModel.isSearching,
                                onClear: {
                                    viewModel.clearSearch()
                                },
                                onCancel: {
                                    viewModel.dismissSearch()
                                }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        if !viewModel.folders.isEmpty {
                            FolderFilterChipsView(
                                folders: viewModel.folders,
                                selectedFolderID: $viewModel.selectedFolderID
                            )
                        }

                        if viewModel.showsInitialLoadingIndicator && !viewModel.hasCompletedInitialLoad {
                            LoadingLecturesPlaceholderView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if viewModel.lectures.isEmpty {
                            EmptyLecturesPlaceholderView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if viewModel.filteredLectures.isEmpty, viewModel.hasActiveSearchQuery {
                            EmptySearchResultsPlaceholderView(query: viewModel.searchText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else if viewModel.filteredLectures.isEmpty, viewModel.selectedFolderID != nil {
                            EmptyFolderPlaceholderView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 0) {
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
                                    .onAppear {
                                        viewModel.loadMoreLecturesIfNeeded(currentLectureID: lecture.id)
                                    }

                                    if lecture.id != displayedLectures.last?.id {
                                        Divider()
                                            .padding(.leading, 58)
                                    }
                                }

                                if viewModel.hasMoreLecturesToDisplay {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, showsFloatingSearchBar ? searchBarReservedHeight + 8 : 0)
                    .padding(.bottom, 100)
                }
                .coordinateSpace(name: LecturesListContainerSpace.name)
                .onPreferenceChange(LecturesListScrollOffsetPreferenceKey.self) { newOffset in
                    handleScrollOffsetChange(currentOffset: newOffset, viewModel: viewModel)
                    currentScrollOffset = newOffset
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            handleScrollDragChange(
                                translationHeight: value.translation.height,
                                viewModel: viewModel
                            )
                        }
                )
            }
            .background(Color(.systemGray6))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $viewModel.selectedLecture) { lecture in
                LectureDetailView(
                    lecture: lecture,
                    repository: repository,
                    processingService: processingService,
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
                            return true
                        case .rejected(let message):
                            await MainActor.run {
                                viewModel.showToast(message)
                            }
                            return false
                        }
                    }
                )
            }
            .overlay(alignment: .bottomTrailing) {
                if viewModel.activeSheet == nil && viewModel.recorderViewModel == nil {
                    FloatingRecordButton {
                        viewModel.requestFlow(.record, hasConfirmedAIProcessingConsent: hasConfirmedAIProcessingConsent)
                    }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
            }
            .overlay {
                if viewModel.recorderViewModel != nil {
                    Button {
                        viewModel.recorderViewModel = nil
                    } label: {
                        Color.black.opacity(0.18)
                            .ignoresSafeArea()
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                if viewModel.isAIConsentPresented {
                    Button {
                        viewModel.dismissAIConsent()
                    } label: {
                        Color.black.opacity(0.28)
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
                if showsFloatingSearchBar {
                    LecturesSearchBarView(
                        text: $viewModel.searchText,
                        isSearching: viewModel.isSearching,
                        onClear: {
                            viewModel.clearSearch()
                        },
                        onCancel: {
                            viewModel.dismissSearch()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, stickySearchTopInset)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if let toastMessage = viewModel.toastMessage {
                    ToastBannerView(message: toastMessage)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage != nil)
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: viewModel.recorderViewModel != nil)
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showsInlineSearchBar)
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showsFloatingSearchBar)
            .sensoryFeedback(.success, trigger: viewModel.removalFeedbackToken)
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.importFeedbackToken)
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
                                let folderName = viewModel.removeLectureFromFolder(lectureID)
                                viewModel.closeActiveSheet()
                                viewModel.removalFeedbackToken += 1
                                viewModel.showToast(
                                    folderName.map { "Removed from \($0)." } ?? "Removed from folder."
                                )
                            },
                            onEditTitle: {},
                            onShare: {},
                            onDelete: {
                                viewModel.requestDelete(lecture)
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
                }
            ) {
                YouTubeImportSheetView(
                    onClose: {
                        viewModel.dismissYouTubeImportSheet()
                    },
                    onSubmit: { urlString in
                        await viewModel.submitYouTubeImport(urlString)
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
                .presentationDetents([.height(ImportLimitSheetView.preferredSheetHeight)])
                .presentationDragIndicator(.visible)
            }
            .alert("Import", isPresented: $viewModel.isImportAlertPresented) {
                Button("OK") {
                    viewModel.dismissImportAlert()
                }
            } message: {
                Text(viewModel.importAlertMessage)
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
                Text("Delete \"\(lecture.title)\"? This action cannot be undone.")
            }
            .task {
                await viewModel.load()
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
        activeFileImport = fileImport
        isFileImporterPresented = true
    }

    private func handleScrollOffsetChange(currentOffset: CGFloat, viewModel: LecturesListViewModel) {
        if currentOffset < 40 {
            viewModel.hideSearchForScrollIfNeeded()
        }
    }

    private func handleScrollDragChange(
        translationHeight: CGFloat,
        viewModel: LecturesListViewModel
    ) {
        guard currentScrollOffset > 140 else {
            return
        }

        if translationHeight > 18 {
            viewModel.presentSearchFromScroll()
        } else if translationHeight < -24 {
            viewModel.hideSearchForScrollIfNeeded()
        }
    }
}

private enum LecturesListContainerSpace {
    static let name = "lecturesListContainer"
}

private struct LecturesListScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct LecturesListScrollOffsetReader: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: LecturesListScrollOffsetPreferenceKey.self,
                    value: max(-geometry.frame(in: .named(LecturesListContainerSpace.name)).minY, 0)
                )
        }
        .frame(height: 0)
    }
}

private struct ToastBannerView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.88))
            .clipShape(.rect(cornerRadius: 14))
            .shadow(radius: 10, y: 4)
    }
}

private struct EmptyLecturesPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Text("No recordings yet")
        } description: {
            Text("Tap the mic button to start recording.")
        }
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
    private let folders = MockLectures.makeFolders()
    @State private var paywallPresentationModel = PaywallPresentationModel()

    var body: some View {
        VStack(spacing: 0) {
            previewHeader
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PremiumBannerView(paywallPresentationModel: paywallPresentationModel)
                    QuickActionsStripView {} onImportText: {} onImportYouTube: {} onImportPDF: {}
                    previewSectionHeader
                    LecturesSearchBarView(
                        text: .constant("Plant"),
                        isSearching: false,
                        onClear: {},
                        onCancel: {}
                    )
                    previewFolderChips

                    if let firstLecture = lectures.first {
                        LectureRowView(lecture: firstLecture, onOpen: {}, onMore: {})
                    }

                    if lectures.count > 1 {
                        LectureRowView(lecture: lectures[1], onOpen: {}, onMore: {})
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .background(Color(.systemGray6))
    }

    private var previewHeader: some View {
        HStack {
            Text("LectraAI")
                .font(.title)
                .bold()
            Spacer()
            Image(systemName: "gearshape")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.05))
                .clipShape(.circle)
        }
    }

    private var previewSectionHeader: some View {
        RecordingsSectionHeaderView(
            foldersDestination: FoldersScreen(viewModel: LecturesListViewModel(repository: MockLectureRepository())),
            showsFoldersNavigation: false,
            onSearchTap: {}
        )
    }

    private var previewFolderChips: some View {
        ScrollView(.horizontal) {
            HStack {
                previewChip(title: "All", isSelected: true)

                if !folders.isEmpty {
                    previewChip(title: folders[0].name, isSelected: false)
                }

                if folders.count > 1 {
                    previewChip(title: folders[1].name, isSelected: false)
                }

                if folders.count > 2 {
                    previewChip(title: folders[2].name, isSelected: false)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func previewChip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? .black : .white)
            .clipShape(.rect(cornerRadius: 16))
    }
}
