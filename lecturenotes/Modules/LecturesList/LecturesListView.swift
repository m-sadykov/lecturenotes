import SwiftUI
import UniformTypeIdentifiers

struct LecturesListView: View {
    @State var viewModel: LecturesListViewModel
    @State private var selectedLecture: Lecture?
    @State private var isImporterPresented = false
    @State private var isImportAlertPresented = false
    @State private var importAlertMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HomeHeaderView()
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PremiumBannerView()
                        QuickActionsStripView {
                            isImporterPresented = true
                        }
                        RecordingsSectionHeaderView()

                        if viewModel.isLoading {
                            ProgressView("Loading lectures")
                                .frame(maxWidth: .infinity)
                        } else {
                            LazyVStack {
                                ForEach(viewModel.filteredLectures) { lecture in
                                    NavigationLink(value: lecture) {
                                        LectureRowView(lecture: lecture) {
                                            selectedLecture = lecture
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGray6))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Lecture.self) { lecture in
                LectureDetailView(lecture: lecture)
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingRecordButton()
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
            .sheet(item: $selectedLecture) { lecture in
                RecordingActionsSheet(
                    lecture: lecture,
                    onAddToFolder: {},
                    onEditTitle: {},
                    onShare: {},
                    onDelete: {
                        selectedLecture = nil
                    }
                )
                .presentationDetents([.height(270)])
                .presentationCornerRadius(28)
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleAudioImport(result)
            }
            .alert("Import Recording", isPresented: $isImportAlertPresented) {
                Button("OK") {}
            } message: {
                Text(importAlertMessage)
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func handleAudioImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importAlertMessage = "No audio file was selected."
                isImportAlertPresented = true
                return
            }
            importAlertMessage = "Selected: \(url.lastPathComponent)"
            isImportAlertPresented = true
        case .failure(let error):
            importAlertMessage = "Import failed: \(error.localizedDescription)"
            isImportAlertPresented = true
        }
    }
}

#Preview {
    LecturesListView(viewModel: LecturesListViewModel(repository: MockLectureRepository()))
}
