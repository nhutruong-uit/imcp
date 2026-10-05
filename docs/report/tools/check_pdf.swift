// Checks / previews the report PDF (macOS, uses the system PDFKit).
//   swift docs/report/tools/check_pdf.swift check <pdf> [text to find...]
//       Prints the page count and the pages containing each text. Exit code 1 if the PDF still has Word field
//       errors (table of contents/cross references not updated: "Error! Bookmark not defined"...).
//   swift docs/report/tools/check_pdf.swift pages <pdf> <output folder> <pages...>
//       Exports PNG images of the pages (e.g. 56 57 70-72) and a contact sheet overview.png to check the layout.
import AppKit
import PDFKit

// Word prints these texts in place of a broken field (English and Vietnamese Word)
let wordFieldErrors = ["Error! Bookmark not defined", "Error! Reference source not found",
                       "No table of contents entries found", "Lỗi! Không tìm thấy nguồn tham chiếu",
                       "Lỗi! Thẻ đánh dấu chưa được xác định"]

func openPdf(_ path: String) -> PDFDocument {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
        FileHandle.standardError.write("Cannot open \(path)\n".data(using: .utf8)!)
        exit(2)
    }
    return doc
}

func pagesContaining(_ doc: PDFDocument, _ text: String) -> [Int] {
    (0..<doc.pageCount).filter { doc.page(at: $0)?.string?.contains(text) == true }.map { $0 + 1 }
}

func check(_ a: [String]) {
    let doc = openPdf(a[0])
    print("Pages: \(doc.pageCount)")
    for text in a.dropFirst() {
        let pages = pagesContaining(doc, text)
        print("\"\(text)\" -> \(pages.isEmpty ? "not found" : "page " + pages.map(String.init).joined(separator: ", "))")
    }
    var hasErrors = false
    for text in wordFieldErrors {
        let pages = pagesContaining(doc, text)
        if !pages.isEmpty {
            print("WORD FIELD ERROR \"\(text)\" on page \(pages.map(String.init).joined(separator: ", "))")
            hasErrors = true
        }
    }
    if hasErrors { exit(1) }
    print("No Word field errors.")
}

func exportPages(_ a: [String]) {
    let doc = openPdf(a[0])
    let folder = a[1]
    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    var pages: [Int] = []
    for t in a.dropFirst(2) {
        let p = t.split(separator: "-").compactMap { Int($0) }
        if p.count == 2 { pages += Array(p[0]...p[1]) } else if p.count == 1 { pages.append(p[0]) }
    }
    pages = pages.filter { $0 >= 1 && $0 <= doc.pageCount }
    var images: [NSImage] = []
    for t in pages {
        let page = doc.page(at: t - 1)!
        let r = page.bounds(for: .mediaBox)
        let img = page.thumbnail(of: NSSize(width: r.width * 1.3, height: r.height * 1.3), for: .mediaBox)
        images.append(img)
        if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: String(format: "%@/page_%03d.png", folder, t)))
        }
    }
    guard !images.isEmpty else { print("No valid page."); exit(2) }
    // Contact sheet: at most 4 pages per row, page number above each page
    let cols = min(4, images.count), rows = (images.count + cols - 1) / cols
    let w: CGFloat = 600, h = w * images[0].size.height / images[0].size.width
    let W = CGFloat(cols) * (w + 12) + 12, H = CGFloat(rows) * (h + 34) + 12
    let sheet = NSImage(size: NSSize(width: W, height: H))
    sheet.lockFocus()
    NSColor(white: 0.85, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()
    for (i, img) in images.enumerated() {
        let x = 12 + CGFloat(i % cols) * (w + 12), y = H - CGFloat(i / cols + 1) * (h + 34)
        img.draw(in: NSRect(x: x, y: y, width: w, height: h))
        ("Page \(pages[i])" as NSString).draw(at: NSPoint(x: x, y: y + h + 8),
                                              withAttributes: [.font: NSFont.boldSystemFont(ofSize: 16)])
    }
    sheet.unlockFocus()
    if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: folder + "/overview.png"))
    }
    print("Exported \(pages.count) pages to \(folder) (overview.png is the contact sheet).")
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "check" where args.count >= 2: check(Array(args.dropFirst()))
case "pages" where args.count >= 4: exportPages(Array(args.dropFirst()))
default:
    print("Usage: check_pdf.swift check <pdf> [text...] | pages <pdf> <output folder> <pages...>")
    exit(2)
}
