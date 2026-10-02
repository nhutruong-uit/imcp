// Kiểm tra / xem nhanh file PDF báo cáo (macOS, dùng PDFKit có sẵn của hệ điều hành).
//   swift docs/report/cong_cu/kiem_tra_pdf.swift kiemtra <pdf> [chuỗi cần tìm...]
//       In số trang và các trang chứa từng chuỗi. Mã thoát 1 nếu PDF còn lỗi field của Word
//       (mục lục/tham chiếu chưa cập nhật: "Error! Bookmark not defined"...).
//   swift docs/report/cong_cu/kiem_tra_pdf.swift anh <pdf> <thư mục ra> <trang...>
//       Xuất ảnh PNG các trang (vd: 56 57 70-72) và ảnh ghép tong_hop.png để xem nhanh bố cục.
import AppKit
import PDFKit

let loiWord = ["Error! Bookmark not defined", "Error! Reference source not found",
               "No table of contents entries found", "Lỗi! Không tìm thấy nguồn tham chiếu",
               "Lỗi! Thẻ đánh dấu chưa được xác định"]

func moPdf(_ duongDan: String) -> PDFDocument {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: duongDan)) else {
        FileHandle.standardError.write("Không mở được \(duongDan)\n".data(using: .utf8)!)
        exit(2)
    }
    return doc
}

func trangChua(_ doc: PDFDocument, _ chuoi: String) -> [Int] {
    (0..<doc.pageCount).filter { doc.page(at: $0)?.string?.contains(chuoi) == true }.map { $0 + 1 }
}

func kiemTra(_ a: [String]) {
    let doc = moPdf(a[0])
    print("Số trang: \(doc.pageCount)")
    for chuoi in a.dropFirst() {
        let ds = trangChua(doc, chuoi)
        print("\"\(chuoi)\" -> \(ds.isEmpty ? "không có" : "trang " + ds.map(String.init).joined(separator: ", "))")
    }
    var coLoi = false
    for chuoi in loiWord {
        let ds = trangChua(doc, chuoi)
        if !ds.isEmpty {
            print("LỖI FIELD WORD \"\(chuoi)\" ở trang \(ds.map(String.init).joined(separator: ", "))")
            coLoi = true
        }
    }
    if coLoi { exit(1) }
    print("Không có lỗi field của Word.")
}

func xuatAnh(_ a: [String]) {
    let doc = moPdf(a[0])
    let thuMuc = a[1]
    try? FileManager.default.createDirectory(atPath: thuMuc, withIntermediateDirectories: true)
    var trang: [Int] = []
    for t in a.dropFirst(2) {
        let p = t.split(separator: "-").compactMap { Int($0) }
        if p.count == 2 { trang += Array(p[0]...p[1]) } else if p.count == 1 { trang.append(p[0]) }
    }
    trang = trang.filter { $0 >= 1 && $0 <= doc.pageCount }
    var anh: [NSImage] = []
    for t in trang {
        let page = doc.page(at: t - 1)!
        let r = page.bounds(for: .mediaBox)
        let img = page.thumbnail(of: NSSize(width: r.width * 1.3, height: r.height * 1.3), for: .mediaBox)
        anh.append(img)
        if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: String(format: "%@/trang_%03d.png", thuMuc, t)))
        }
    }
    guard !anh.isEmpty else { print("Không có trang hợp lệ."); exit(2) }
    // Ảnh ghép tối đa 4 trang mỗi hàng, ghi số trang phía trên
    let cot = min(4, anh.count), hang = (anh.count + cot - 1) / cot
    let w: CGFloat = 600, h = w * anh[0].size.height / anh[0].size.width
    let W = CGFloat(cot) * (w + 12) + 12, H = CGFloat(hang) * (h + 34) + 12
    let tong = NSImage(size: NSSize(width: W, height: H))
    tong.lockFocus()
    NSColor(white: 0.85, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()
    for (i, img) in anh.enumerated() {
        let x = 12 + CGFloat(i % cot) * (w + 12), y = H - CGFloat(i / cot + 1) * (h + 34)
        img.draw(in: NSRect(x: x, y: y, width: w, height: h))
        ("Trang \(trang[i])" as NSString).draw(at: NSPoint(x: x, y: y + h + 8),
                                                 withAttributes: [.font: NSFont.boldSystemFont(ofSize: 16)])
    }
    tong.unlockFocus()
    if let tiff = tong.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: thuMuc + "/tong_hop.png"))
    }
    print("Đã xuất \(trang.count) trang vào \(thuMuc) (tong_hop.png là ảnh ghép).")
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "kiemtra" where args.count >= 2: kiemTra(Array(args.dropFirst()))
case "anh" where args.count >= 4: xuatAnh(Array(args.dropFirst()))
default:
    print("Cách dùng: kiem_tra_pdf.swift kiemtra <pdf> [chuỗi...] | anh <pdf> <thư mục ra> <trang...>")
    exit(2)
}
