import Foundation
import UniformTypeIdentifiers

/// Classifies scanned file records into storage taxonomy (runs only after filesystem scan).
enum StorageClassifier: Sendable {
    struct Context: Sendable {
        let homePath: String
        let libraryPath: String
    }

    static func makeContext(homeURL: URL) -> Context {
        let homePath = homeURL.standardizedFileURL.path
        let libraryPath = homeURL.appendingPathComponent("Library", isDirectory: true).path
        return Context(homePath: homePath, libraryPath: libraryPath)
    }

    static func classify(records: [DiskScanFileRecord], homeURL: URL) -> [StorageCompositionCategory: Int64] {
        let context = makeContext(homeURL: homeURL)
        var totals: [StorageCompositionCategory: Int64] = [:]
        for record in records where record.allocatedBytes > 0 {
            let category = category(for: record, context: context)
            totals[category, default: 0] += record.allocatedBytes
        }
        return totals
    }

    static func category(for record: DiskScanFileRecord, homeURL: URL) -> StorageCompositionCategory {
        category(for: record, context: makeContext(homeURL: homeURL))
    }

    static func category(
        for record: DiskScanFileRecord,
        context: Context
    ) -> StorageCompositionCategory {
        let homePath = context.homePath
        let libraryPath = context.libraryPath
        let path = normalizeAnalyzerPath(record.absolutePath)

        if isInsideApplicationBundle(path) {
            return .applications
        }

        if path.hasPrefix("/Applications/") || path.contains("/Applications/") && path.hasSuffix(".app") {
            return .applications
        }

        if path.hasPrefix("/System/") || path.hasPrefix("/private/var/db/") {
            return .systemFiles
        }

        if path.hasPrefix("/Library/") && !path.hasPrefix(libraryPath) {
            return .systemFiles
        }

        if path.hasPrefix("\(libraryPath)/Developer") {
            return .developer
        }

        if path.hasPrefix("\(libraryPath)/Caches") {
            return .caches
        }

        let appDataRoots = [
            "\(libraryPath)/Application Support",
            "\(libraryPath)/Containers",
            "\(libraryPath)/Group Containers",
        ]
        if appDataRoots.contains(where: { path.hasPrefix($0) }) {
            return .applicationData
        }

        if let extCategory = categoryFromContentType(path: path, fileExtension: record.fileExtension) {
            return extCategory
        }

        let userFolderRoots = [
            "\(homePath)/Documents",
            "\(homePath)/Desktop",
            "\(homePath)/Downloads",
        ]
        if userFolderRoots.contains(where: { path.hasPrefix($0) }) {
            return .documents
        }

        if path.hasPrefix("\(homePath)/Pictures") {
            return .photos
        }
        if path.hasPrefix("\(homePath)/Movies") {
            return .videos
        }
        if path.hasPrefix("\(homePath)/Music") {
            return .audio
        }

        return .otherFiles
    }

    private static func normalizeAnalyzerPath(_ absolutePath: String) -> String {
        let dataPrefix = "/System/Volumes/Data"
        if absolutePath.hasPrefix(dataPrefix) {
            let suffix = absolutePath.dropFirst(dataPrefix.count)
            if suffix.isEmpty { return "/" }
            return String(suffix)
        }
        return absolutePath
    }

    private static func isInsideApplicationBundle(_ path: String) -> Bool {
        let components = path.split(separator: "/").map(String.init)
        return components.contains { $0.hasSuffix(".app") }
    }

    private static func categoryFromContentType(
        path: String,
        fileExtension: String?
    ) -> StorageCompositionCategory? {
        guard let ext = fileExtension?.lowercased(), !ext.isEmpty else { return nil }
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .image) { return .photos }
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .videos }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .archive) || type.conforms(to: .zip) { return .archives }
            if type.conforms(to: .pdf) || type.conforms(to: .spreadsheet) || type.conforms(to: .presentation)
                || type.conforms(to: .text) || type.conforms(to: .sourceCode)
            {
                return .documents
            }
        }

        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tif", "tiff", "bmp", "raw":
            return .photos
        case "mp4", "mov", "m4v", "mkv", "avi", "webm":
            return .videos
        case "mp3", "m4a", "aac", "wav", "flac", "aiff":
            return .audio
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar":
            return .archives
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "rtf", "pages", "numbers", "key":
            return .documents
        default:
            return nil
        }
    }
}
