import SwiftUI

struct RecordingsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var isPresentingBrowse = false

    var recordingsStorage: RecordingsStorage {
        model.recordingsStorage
    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack {
                    Text(recordingsStorage.numberOfRecordingsString())
                        .font(.title2)
                    Text("Total recordings")
                        .font(.subheadline)
                }
                Spacer()
                VStack {
                    Text(recordingsStorage.totalSizeString())
                        .font(.title2)
                    Text("Total size")
                        .font(.subheadline)
                }
                Spacer()
            }
            Form {
                if model.database.debug!.recordingsFolder! {
                    Section {
                        Button {
                            isPresentingBrowse = true
                        } label: {
                            TextItemView(name: "Storage", value: "Locally")
                        }
                        .fileImporter(isPresented: $isPresentingBrowse,
                                      allowedContentTypes: [.folder])
                        { result in
                            switch result {
                            case let .success(folderUrl):
                                if folderUrl.startAccessingSecurityScopedResource() {
                                    defer { folderUrl.stopAccessingSecurityScopedResource() }
                                    var error: NSError?
                                    NSFileCoordinator()
                                        .coordinate(readingItemAt: folderUrl, error: &error) { url in
                                            let keys: [URLResourceKey] = [
                                                .nameKey,
                                                .isDirectoryKey,
                                                .fileSizeKey,
                                                .volumeNameKey,
                                            ]
                                            guard let fileList =
                                                FileManager.default.enumerator(
                                                    at: url,
                                                    includingPropertiesForKeys: keys
                                                )
                                            else {
                                                logger
                                                    .info(
                                                        "*** Unable to access the contents of \(url.path) ***\n"
                                                    )
                                                return
                                            }
                                            for case let file as URL in fileList {
                                                logger
                                                    .info("file: \(file.absoluteString) \(file.fileSize)")
                                                guard file.startAccessingSecurityScopedResource() else {
                                                    continue
                                                }
                                                logger.info("chosen file: \(file.lastPathComponent)")
                                                file.stopAccessingSecurityScopedResource()
                                            }
                                        }
                                }
                            case let .failure(error):
                                logger.debug("Recording error: \(error)")
                            }
                        }
                    }
                }
                Section {
                    List {
                        ForEach(recordingsStorage.database.recordings) { recording in
                            NavigationLink {
                                RecordingsRecordingSettingsView(
                                    recording: recording,
                                    description: recording.description ?? ""
                                )
                            } label: {
                                HStack {
                                    if let image = createThumbnail(path: recording.url()) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 90)
                                    } else {
                                        Image(systemName: "photo")
                                    }
                                    VStack(alignment: .leading) {
                                        Text(recording.startTime.formatted())
                                        Text(recording.length().formatWithSeconds())
                                        Text(recording.subTitle())
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: { indexSet in
                            for index in indexSet {
                                recordingsStorage.database.recordings[index].url().remove()
                            }
                            recordingsStorage.database.recordings.remove(atOffsets: indexSet)
                            recordingsStorage.store()
                        })
                    }
                }
            }
        }
        .navigationTitle("Recordings")
    }
}
