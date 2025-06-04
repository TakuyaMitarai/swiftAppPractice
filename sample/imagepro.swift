import SwiftUI
import SwiftData
import PhotosUI
import Photos
import UniformTypeIdentifiers

// MARK: - EditedImageModel
@Model
class EditedImageModel {
    var id: UUID
    var imageData: Data // 元画像データ（フレーム・マット適用前）
    var matteWidth: Double
    var frameWidth: Double
    var frameRatio: String
    var isFrameEnabled: Bool
    var scale: Double
    var rotationDegrees: Double
    var createdAt: Date
    
    init(imageData: Data, matteWidth: Double = 0.0, frameWidth: Double = 0.0, frameRatio: String = "1:1", isFrameEnabled: Bool = true, scale: Double = 1.0, rotationDegrees: Double = 0.0) {
        self.id = UUID()
        self.imageData = imageData // 元画像データを保存
        self.matteWidth = matteWidth
        self.frameWidth = frameWidth
        self.frameRatio = frameRatio.isEmpty ? "1:1" : frameRatio // 空文字列対策
        self.isFrameEnabled = isFrameEnabled
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.createdAt = Date()
        
        // シミュレータでのデバッグ情報
        print("📱 EditedImageModel作成: ID=\(id), 元画像データサイズ=\(imageData.count) bytes")
    }
}

// MARK: - ImageDisplayView（分離したコンポーネント）
struct ImageDisplayView: View {
    let imageData: Data
    
    var body: some View {
        ZStack {
            if imageData.isEmpty {
                emptyDataView()
            } else {
                createPlatformImage()
                    .onAppear {
                        // このViewが表示されるたびに画像データをデバッグ
                        // debugImageData() // 必要に応じて有効化
                    }
            }
        }
    }
    
    @ViewBuilder
    private func emptyDataView() -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            Text("画像データが空です")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.opacity(0.1))
    }
    
    @ViewBuilder
    private func createPlatformImage() -> some View {
        #if os(macOS)
        if let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .onAppear {
                    // print("✅ NSImage作成成功 (ImageDisplayView): \(nsImage.size)")
                }
        } else {
            fallbackView(reason: "NSImage作成失敗")
        }
        #else
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .onAppear {
                    // print("✅ UIImage作成成功 (ImageDisplayView): \(uiImage.size)")
                }
        } else {
            fallbackView(reason: "UIImage作成失敗")
        }
        #endif
    }
    
    @ViewBuilder
    private func fallbackView(reason: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: "photo.fill")
                .font(.system(size: 30))
                .foregroundColor(.red.opacity(0.7))
            Text("画像表示エラー")
                .font(.caption)
                .foregroundColor(.red)
            Text(reason)
                .font(.caption2)
                .foregroundColor(.red.opacity(0.8))
            Text("データ: \(imageData.count) bytes")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if imageData.count >= 8 {
                let headerBytes = imageData.prefix(8)
                let hexString = headerBytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                Text("ヘッダ: \(hexString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .onAppear {
                        // fallbackViewが表示された際に詳細なデバッグ情報を出力
                         print("ImageDisplayView Fallback: \(reason)")
                         debugImageData()
                    }
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.yellow.opacity(0.2))
    }
    
    private func debugImageData() {
        print("🔍 ImageDisplayView Debug:")
        print("  - データサイズ: \(imageData.count) bytes")
        
        if imageData.isEmpty {
            print("  - 形式: データが空です")
            return
        }
        
        let minBytesForHeaderCheck = 12
        if imageData.count >= minBytesForHeaderCheck {
            let header = imageData.prefix(minBytesForHeaderCheck)
            let hexString = header.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("  - 先頭\(minBytesForHeaderCheck)バイト (Hex): \(hexString)")

            let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            let jpegSoi = Data([0xFF, 0xD8, 0xFF])
            let gifHeader89a = "GIF89a".data(using: .ascii)!
            let gifHeader87a = "GIF87a".data(using: .ascii)!
            let riffHeader = "RIFF".data(using: .ascii)!
            let webpHeader = "WEBP".data(using: .ascii)!

            if imageData.prefix(8).starts(with: pngHeader) {
                print("  - 形式: PNG画像 (シグネチャ一致)")
            } else if imageData.prefix(3).starts(with: jpegSoi) {
                print("  - 形式: JPEG画像 (SOI FF D8 FF..)")
                if imageData.count > 10 { // Check for JFIF or Exif markers
                    let fourthByte = imageData[3]
                    if (0xE0...0xEF).contains(fourthByte) { // APPn markers
                        print("    - JPEG APPn marker: FF E\(String(format:"%X", fourthByte & 0x0F))")
                        if imageData.dropFirst(6).prefix(4).elementsEqual("JFIF".utf8) || imageData.dropFirst(6).prefix(4).elementsEqual("Exif".utf8) {
                             print("    - Likely JFIF or Exif")
                        }
                    }
                }
            } else if imageData.prefix(6).starts(with: gifHeader89a) || imageData.prefix(6).starts(with: gifHeader87a) {
                print("  - 形式: GIF画像")
            } else if imageData.prefix(4).starts(with: riffHeader) && imageData.count >= 12 && imageData.dropFirst(8).prefix(4).starts(with: webpHeader) {
                print("  - 形式: WebP画像")
            } else {
                print("  - 形式: 未知 (上記以外のヘッダー)")
            }
        } else {
             print("  - 形式: データサイズが小さすぎます (\(imageData.count) bytes) ヘッダーチェック不可")
        }
        
        #if os(macOS)
        let image = NSImage(data: imageData)
        print("  - NSImage作成 (デバッグ): \(image != nil ? "成功" : "失敗")")
        if let img = image {
            print("  - 画像サイズ (NSImage): \(img.size)")
        }
        #else
        let image = UIImage(data: imageData)
        print("  - UIImage作成 (デバッグ): \(image != nil ? "成功" : "失敗")")
        if let img = image {
            print("  - 画像サイズ (UIImage): \(img.size)")
        }
        #endif
    }
}

// MARK: - SavedImageGridView（分離したコンポーネント）
struct SavedImageGridView: View {
    let savedImages: [EditedImageModel]
    @Environment(\.modelContext) private var context
    @Binding var selectedEditedModel: EditedImageModel?
    @Binding var showImageEdit: Bool
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
            ForEach(savedImages.prefix(4), id: \.id) { savedImage in
                VStack {
                    Button(action: {
                        print("保存済み画像選択: ID = \(savedImage.id), データサイズ = \(savedImage.imageData.count) bytes")
                        selectedEditedModel = savedImage
                        showImageEdit = true
                    }) {
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                            
                            ImageDisplayView(imageData: savedImage.imageData)
                                .onAppear {
                                     print("SavedImageGridView ImageDisplayView onAppear: ID \(savedImage.id), data size: \(savedImage.imageData.count)")
                                     #if os(iOS)
                                     if UIImage(data: savedImage.imageData) == nil {
                                         print("SavedImageGridView: Failed to create UIImage from saved data for ID \(savedImage.id)")
                                     }
                                     #elseif os(macOS)
                                     if NSImage(data: savedImage.imageData) == nil {
                                         print("SavedImageGridView: Failed to create NSImage from saved data for ID \(savedImage.id)")
                                     }
                                     #endif
                                }
                        }
                        .frame(width: 120, height: 120) // Grid cell size
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                    }
                    
                    VStack(spacing: 2) {
                        Text("Size: \(savedImage.imageData.count / 1024) KB")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if savedImage.matteWidth > 0 || savedImage.frameWidth > 0 {
                            Text("M:\(Int(savedImage.matteWidth)) F:\(Int(savedImage.frameWidth)) R:\(savedImage.frameRatio)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    
                    Button(action: {
                        print("画像削除: \(savedImage.id)")
                        context.delete(savedImage)
                        // try? context.save() // SwiftDataの@Queryは自動的に更新を検知するはず
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .padding(.top, 1)
                }
            }
        }
    }
}

// MARK: - ImageSelectionView
struct ImageSelectionView: View {
    @Query(sort: \EditedImageModel.createdAt, order: .reverse) private var savedImages: [EditedImageModel]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedEditedModel: EditedImageModel? = nil // For re-editing
    @State private var showImageEdit = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) { // Reduced spacing
                newImageSelectionSection
                savedImagesSection
                Spacer()
            }
            .padding()
            .navigationTitle("画像編集")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) { // .automatic for better cross-platform
                    Button("戻る") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItem) { oldItem, newItem in
                handleImageSelection(newItem)
            }
            .onChange(of: showImageEdit) { oldValue, newValue in
                 print("showImageEdit changed from \(oldValue) to: \(newValue)")
                 if !newValue { // When modal is dismissed
                     selectedItem = nil
                     selectedImageData = nil
                     selectedEditedModel = nil
                 }
            }
            .onAppear {
                debugSavedImages()
            }
            #if os(macOS)
            .sheet(isPresented: $showImageEdit) {
                createImageEditView()
            }
            #else
            .fullScreenCover(isPresented: $showImageEdit) {
                createImageEditView()
            }
            #endif
        }
    }
    
    private func debugSavedImages() {
        print("🔍 保存済み画像デバッグ (onAppear ImageSelectionView):")
        print("  - 保存済み画像数: \(savedImages.count)")
        for (index, image) in savedImages.enumerated() {
            print("  - 画像\(index + 1): ID=\(image.id), \(image.imageData.count) bytes, M:\(image.matteWidth), F:\(image.frameWidth), R:\(image.frameRatio)")
            
            if image.imageData.isEmpty {
                 print("    ⚠️ データが空です")
                 continue
            }
            #if os(iOS)
            if UIImage(data: image.imageData) != nil {
                print("    ✅ UIImageとして読み込み可能")
            } else {
                print("    ❌ UIImageとして読み込み失敗")
            }
            #elseif os(macOS)
            if NSImage(data: image.imageData) != nil {
                print("    ✅ NSImageとして読み込み可能")
            } else {
                print("    ❌ NSImageとして読み込み失敗")
            }
            #endif
        }
    }
    
    @ViewBuilder
    private func createImageEditView() -> some View {
        if let editedModel = selectedEditedModel {
            ImageEditView(editedModel: editedModel) // Pass existing model
        } else if let imageData = selectedImageData {
            ImageEditView(imageData: imageData) // Pass new image data
        } else {
            VStack {
                Text("画像データがありません。")
                    .padding()
                Button("閉じる") {
                    showImageEdit = false
                }
            }
        }
    }
    
    private var newImageSelectionSection: some View {
        VStack(spacing: 15) {
            Text("新しい画像を選択").font(.headline)
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .strokeBorder(Color.blue, lineWidth: 2, antialiased: true)
                    .frame(height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 30))
                            Text("写真を選択").padding(.top, 5)
                        }
                        .foregroundColor(.blue)
                    )
            }
            testButton
        }
    }
    
    private var testButton: some View {
        Button("テスト: カラフル画像生成＆編集") {
            let testData = createVisualTestImage()
            print("テスト画像生成: \(testData.count) bytes")
            selectedImageData = testData
            selectedEditedModel = nil // Ensure it's a new edit
            showImageEdit = true
        }
        .padding(.horizontal,15).padding(.vertical, 8)
        .background(Color.green.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    
    private var savedImagesSection: some View {
        Group {
            if !savedImages.isEmpty {
                VStack(spacing: 10) {
                    Text("保存済みの編集画像 (\(savedImages.count)件)").font(.headline)
                    SavedImageGridView(
                        savedImages: savedImages,
                        selectedEditedModel: $selectedEditedModel,
                        showImageEdit: $showImageEdit
                    )
                }
            } else {
                Text("保存済みの画像はありません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
        }
    }
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        Task {
            print("handleImageSelection: newItem is \(newItem == nil ? "nil" : "not nil")")
            guard let item = newItem else {
                await MainActor.run { selectedImageData = nil }
                return
            }
            
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    print("Data読み込み成功 (PhotosPicker): \(data.count) bytes")
                    #if os(iOS)
                    guard UIImage(data: data) != nil else {
                        print("Dataは読み込めたが有効なUIImageではない。フォールバックします。")
                        throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                    #elseif os(macOS)
                    guard NSImage(data: data) != nil else {
                        print("Dataは読み込めたが有効なNSImageではない。フォールバックします。")
                        throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                    #endif
                    
                    await MainActor.run {
                        selectedImageData = data
                        selectedEditedModel = nil // New image, so no existing model
                        showImageEdit = true
                    }
                    return
                }
                print("Data直接読み込み失敗、SwiftUI Image型で試行...")

                // 方法2: SwiftUI Image型で読み込み（Transferableプロトコルに準拠）
                if let image = try await item.loadTransferable(type: Image.self) {
                    print("SwiftUI Image読み込み成功 (PhotosPicker)")
                    
                    // ImageRendererを使用してSwiftUI ImageからDataに変換
                    let renderer = ImageRenderer(content: image.resizable().aspectRatio(contentMode: .fit).frame(width: 512, height: 512))
                    
                    #if os(macOS)
                    if let nsImage = renderer.nsImage,
                       let tiffData = nsImage.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        print("SwiftUI ImageからPNG Dataへ変換成功: \(pngData.count) bytes")
                        await MainActor.run {
                            selectedImageData = pngData
                            selectedEditedModel = nil
                            showImageEdit = true
                        }
                        return
                    }
                    #else
                    if let uiImage = renderer.uiImage,
                       let pngData = uiImage.pngData() {
                        print("SwiftUI ImageからPNG Dataへ変換成功: \(pngData.count) bytes")
                        await MainActor.run {
                            selectedImageData = pngData
                            selectedEditedModel = nil
                            showImageEdit = true
                        }
                        return
                    }
                    #endif
                    
                    print("SwiftUI ImageからDataへの変換失敗。")
                    throw NSError(domain: "ImageError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert SwiftUI Image to Data"])
                }
                
                print("全ての標準的な画像読み込み方法で失敗。")
                throw NSError(domain: "ImageError", code: 3, userInfo: [NSLocalizedDescriptionKey: "All standard loading methods failed."])

            } catch {
                print("画像読み込みまたは変換でエラー発生: \(error.localizedDescription)")
                await MainActor.run {
                    selectedImageData = createVisualTestImage() // フォールバック
                    selectedEditedModel = nil
                    showImageEdit = true
                    print("エラー発生のため、フォールバックテスト画像を使用: \(selectedImageData?.count ?? 0) bytes")
                }
            }
        }
    }
    
    // (createVisualTestImage and createSimpleColoredPNG remain the same)
    private func createVisualTestImage() -> Data {
        let renderer = ImageRenderer(content:
            ZStack {
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 10) {
                    Text("📸").font(.system(size: 60))
                    Text("テスト画像").font(.title.bold()).foregroundColor(.white).shadow(radius: 2)
                    Text("Sample Image").font(.headline).foregroundColor(.white).shadow(radius: 2)
                }.padding().background(Color.black.opacity(0.3)).cornerRadius(15)
                VStack {
                    HStack { Circle().fill(Color.white).frame(width: 30, height: 30); Spacer(); Circle().fill(Color.white).frame(width: 30, height: 30) }
                    Spacer()
                    HStack { Circle().fill(Color.white).frame(width: 30, height: 30); Spacer(); Circle().fill(Color.white).frame(width: 30, height: 30) }
                }.padding(20)
            }.frame(width: 300, height: 300)
        )
        
        #if os(macOS)
        if let nsImage = renderer.nsImage,
           let tiffData = nsImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            return pngData
        }
        #else
        if let uiImage = renderer.uiImage,
           let pngData = uiImage.pngData() {
            return pngData
        }
        #endif
        return createSimpleColoredPNG()
    }
    
    private func createSimpleColoredPNG() -> Data {
        // 8x8のカラフルなPNGデータを手動で作成 (既存のものをそのまま使用)
        return Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x08,0x08, 0x02, 0x00, 0x00, 0x00, 0x4B, 0x6D, 0x29,
            0xDC,0x00, 0x00, 0x00, 0x3E, 0x49, 0x44, 0x41, 0x54,0x78, 0x9C, 0x62, 0xF8, 0xFF, 0xFF, 0x3F,
            0x03,0x3A, 0x00, 0x01, 0x00, 0x18, 0x60, 0x00, 0xFF,0xFF, 0xFF, 0x18, 0x18, 0x00, 0xFF, 0x00,
            0x00,0x18, 0x18, 0x00, 0x00, 0xFF, 0x00, 0x18, 0x18,0x00, 0x00, 0x00, 0xFF, 0x18, 0x18, 0x60,
            0xFF,0xFF, 0x00, 0x18, 0x18, 0x60, 0xFF, 0x00, 0xFF,0x18, 0x18, 0x60, 0x00, 0xFF, 0xFF, 0x18,
            0x18,0x00, 0x00, 0x00, 0x00, 0x07, 0x0F, 0x03, 0x6F,0x2F, 0x99, 0x8E, 0x0C,0x00, 0x00, 0x00,
            0x00, 0x49, 0x45, 0x4E, 0x44,0xAE, 0x42, 0x60, 0x82
        ])
    }
}

// MARK: - ImageEditView
struct ImageEditView: View {
    // 編集対象のデータ。新規の場合はimageDataのみ、再編集の場合はeditedModelから取得
    private var sourceImageData: Data
    private var sourceEditedModel: EditedImageModel?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentImageData: Data // 実際に表示・操作する画像データ
    @State private var scale: CGFloat
    @State private var rotation: Angle
    @State private var showMatteControl = false
    @State private var showFrameControl = false
    @State private var matteWidth: Double
    @State private var frameWidth: Double
    @State private var frameRatio: String
    @State private var isFrameEnabled: Bool // フレームのオンオフ
    @State private var saveAlert: SaveAlert?
    
    enum SaveAlert: Identifiable {
        case success, photoLibraryError, swiftDataError
        
        var id: Int {
            switch self {
            case .success: return 1
            case .photoLibraryError: return 2
            case .swiftDataError: return 3
            }
        }
    }
    
    let frameRatios = ["1:1", "3:4", "4:3", "2:3", "3:2", "9:16", "16:9"]
    
    var maxMatteWidth: Double { 30.0 } // 80.0から30.0に変更
    var maxFrameWidth: Double { 150.0 } // 元は150でしたが、合計で太くなりすぎるため調整
    
    // マット幅に基づいてフレームの最小値を計算
    var minFrameWidth: Double {
        if !isFrameEnabled { return 0.0 }
        // マット幅が0なら最小値も0、そうでなければ小さな値
        return matteWidth <= 0 ? 0.0 : max(0.5, matteWidth * 0.3)
    }
    
    // イニシャライザ：新規画像用
    init(imageData: Data) {
        self.sourceImageData = imageData
        self.sourceEditedModel = nil
        
        _currentImageData = State(initialValue: imageData)
        _scale = State(initialValue: 1.0)
        _rotation = State(initialValue: .zero)
        _matteWidth = State(initialValue: 0.0)
        _frameWidth = State(initialValue: 0.0)
        _frameRatio = State(initialValue: "1:1") // デフォルト値
        _isFrameEnabled = State(initialValue: true)
    }

    // イニシャライザ：既存モデル編集用
    init(editedModel: EditedImageModel) {
        self.sourceImageData = editedModel.imageData
        self.sourceEditedModel = editedModel
        
        _currentImageData = State(initialValue: editedModel.imageData)
        _scale = State(initialValue: CGFloat(editedModel.scale))
        _rotation = State(initialValue: .degrees(editedModel.rotationDegrees))
        _matteWidth = State(initialValue: editedModel.matteWidth)
        _frameWidth = State(initialValue: editedModel.frameWidth)
        _frameRatio = State(initialValue: editedModel.frameRatio.isEmpty ? "1:1" : editedModel.frameRatio)
        _isFrameEnabled = State(initialValue: editedModel.isFrameEnabled)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.opacity(0.15).ignoresSafeArea() // Slightly darker background
                VStack(spacing: 15) {
                    imageDisplaySection
                    controlSection
                    Spacer() // Push controls up if space allows
                }
                .padding()
            }
            .navigationTitle(sourceEditedModel == nil ? "新規画像編集" : "画像再編集")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { // Standard placement
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) { // Standard placement
                    Button("保存") { saveEditedImage() }
                }
            }
            .onAppear {
                print("ImageEditView onAppear: 元画像データサイズ = \(currentImageData.count) bytes")
                if let model = sourceEditedModel {
                    print("編集状態をモデルから復元: \(model.id)")
                    print("復元設定: マット=\(model.matteWidth), フレーム=\(model.frameWidth), 比率=\(model.frameRatio), フレーム有効=\(model.isFrameEnabled)")
                } else {
                    print("新規画像として編集開始")
                }
            }
            .alert(item: $saveAlert) { alert in
                switch alert {
                case .success:
                    return Alert(
                        title: Text("保存完了"),
                        message: Text("画像をSwiftDataとフォトライブラリの両方に保存しました"),
                        dismissButton: .default(Text("OK"))
                    )
                case .photoLibraryError:
                    return Alert(
                        title: Text("フォトライブラリ保存エラー"),
                        message: Text("フォトライブラリへの保存に失敗しました。設定で写真へのアクセスを許可してください。"),
                        dismissButton: .default(Text("OK"))
                    )
                case .swiftDataError:
                    return Alert(
                        title: Text("データ保存エラー"),
                        message: Text("アプリ内データの保存に失敗しました"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .background(Color.white) // 完全に不透明な背景を追加
    }
    
    private func parseAspectRatio(_ ratioString: String) -> CGFloat {
        let components = ratioString.split(separator: ":")
        if components.count == 2,
           let widthComponent = Double(components[0]),
           let heightComponent = Double(components[1]),
           heightComponent != 0 {
            return CGFloat(widthComponent / heightComponent)
        }
        print("アスペクト比パース失敗: \(ratioString), デフォルト1:1を使用")
        return 1.0 // Default to 1:1 if parsing fails
    }
    
    private func calculateImageDimensions(availableWidth: CGFloat, availableHeight: CGFloat, targetAspectRatio: CGFloat, matteWidth: Double, frameWidth: Double) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) {
        // ステップ1: 元画像の実際のアスペクト比とサイズを取得
        let originalImageSize = getOriginalImageSize()
        let originalImageAspectRatio = originalImageSize.width / originalImageSize.height
        print("🖼️ 元画像のアスペクト比: \(originalImageAspectRatio)")
        print("🖼️ フレーム比率: \(targetAspectRatio)")
        print("🔲 フレーム有効: \(isFrameEnabled)")
        
        // ステップ2: 保存と同じスケール係数を使用
        let scaleToOriginal = max(originalImageSize.width, originalImageSize.height) / 800.0
        let baseDisplaySize: CGFloat = 200.0
        
        // 元画像の表示サイズを決定（常に完全表示）
        let originalImageWidth: CGFloat
        let originalImageHeight: CGFloat
        
        if originalImageAspectRatio > 1 {
            // 横長
            originalImageWidth = baseDisplaySize
            originalImageHeight = baseDisplaySize / originalImageAspectRatio
        } else {
            // 縦長・正方形
            originalImageHeight = baseDisplaySize
            originalImageWidth = baseDisplaySize * originalImageAspectRatio
        }
        
        // ステップ3: 保存と同じマット・フレーム厚さ計算（比例スケール適用）
        let matteThickness = CGFloat(matteWidth) * scaleToOriginal
        let frameThickness = isFrameEnabled ? CGFloat(frameWidth) * scaleToOriginal : 0
        
        // UI表示用のスケールファクター（保存時のスケールとは別）
        let displayScale = baseDisplaySize / max(originalImageSize.width, originalImageSize.height)
        let scaledMatteThickness = matteThickness * displayScale
        let scaledFrameThickness = frameThickness * displayScale
        
        if isFrameEnabled {
            // フレーム有効時：指定比率で最終サイズを決定
            let imageWithMatteWidth = originalImageWidth + (scaledMatteThickness * 2)
            let imageWithMatteHeight = originalImageHeight + (scaledMatteThickness * 2)
            
            // フレーム比率に合わせて最終サイズを調整
            let finalContentWidth: CGFloat
            let finalContentHeight: CGFloat
            
            if targetAspectRatio > (imageWithMatteWidth / imageWithMatteHeight) {
                // より横長に → 高さ基準で幅を調整
                finalContentHeight = imageWithMatteHeight
                finalContentWidth = finalContentHeight * targetAspectRatio
            } else {
                // より縦長に → 幅基準で高さを調整
                finalContentWidth = imageWithMatteWidth
                finalContentHeight = finalContentWidth / targetAspectRatio
            }
            
            let totalWidth = finalContentWidth + (scaledFrameThickness * 2)
            let totalHeight = finalContentHeight + (scaledFrameThickness * 2)
            
            // 画面に収まるようにスケール
            let maxAllowedWidth = availableWidth * 0.85
            let maxAllowedHeight = availableHeight * 0.85
            let scaleFactorForScreen = min(1.0, min(maxAllowedWidth / totalWidth, maxAllowedHeight / totalHeight))
            
            print("🔍 UI表示計算（フレーム有効）:")
            print("  元画像実サイズ: \(originalImageSize.width) x \(originalImageSize.height)")
            print("  元画像表示サイズ: \(originalImageWidth) x \(originalImageHeight)")
            print("  保存用スケール係数: \(scaleToOriginal)")
            print("  表示用スケール係数: \(displayScale)")
            print("  マット厚さ（保存用）: \(matteThickness)px")
            print("  マット厚さ（表示用）: \(scaledMatteThickness)px")
            print("  フレーム厚さ（保存用）: \(frameThickness)px")
            print("  フレーム厚さ（表示用）: \(scaledFrameThickness)px")
            print("  マット込み: \(imageWithMatteWidth) x \(imageWithMatteHeight)")
            print("  最終コンテンツ: \(finalContentWidth) x \(finalContentHeight)")
            print("  最終全体: \(totalWidth) x \(totalHeight)")
            print("  画面フィット用スケール: \(scaleFactorForScreen)")
            
            return (
                originalImageWidth * scaleFactorForScreen,
                originalImageHeight * scaleFactorForScreen,
                totalWidth * scaleFactorForScreen,
                totalHeight * scaleFactorForScreen,
                scaledMatteThickness * scaleFactorForScreen
            )
        } else {
            // フレーム無効時：元画像＋マットのみ
            let totalWidth = originalImageWidth + (scaledMatteThickness * 2)
            let totalHeight = originalImageHeight + (scaledMatteThickness * 2)
            
            let maxAllowedWidth = availableWidth * 0.85
            let maxAllowedHeight = availableHeight * 0.85
            let scaleFactorForScreen = min(1.0, min(maxAllowedWidth / totalWidth, maxAllowedHeight / totalHeight))
            
            print("🔍 UI表示計算（フレーム無効）:")
            print("  元画像実サイズ: \(originalImageSize.width) x \(originalImageSize.height)")
            print("  元画像表示サイズ: \(originalImageWidth) x \(originalImageHeight)")
            print("  保存用スケール係数: \(scaleToOriginal)")
            print("  表示用スケール係数: \(displayScale)")
            print("  マット厚さ（保存用）: \(matteThickness)px")
            print("  マット厚さ（表示用）: \(scaledMatteThickness)px")
            print("  最終全体: \(totalWidth) x \(totalHeight)")
            print("  画面フィット用スケール: \(scaleFactorForScreen)")
            
            return (
                originalImageWidth * scaleFactorForScreen,
                originalImageHeight * scaleFactorForScreen,
                totalWidth * scaleFactorForScreen,
                totalHeight * scaleFactorForScreen,
                scaledMatteThickness * scaleFactorForScreen
            )
        }
    }
    
    private func getOriginalImageSize() -> CGSize {
        #if os(macOS)
        if let nsImage = NSImage(data: currentImageData) {
            return nsImage.size
        }
        #else
        if let uiImage = UIImage(data: currentImageData) {
            return uiImage.size
        }
        #endif
        
        print("⚠️ 元画像のサイズ取得失敗、800x800を使用")
        return CGSize(width: 800, height: 800) // フォールバック
    }
    
    private func getOriginalImageMetadata() -> [String: Any]? {
        #if os(iOS)
        guard let imageSource = CGImageSourceCreateWithData(currentImageData as CFData, nil),
              CGImageSourceGetCount(imageSource) > 0 else {
            print("⚠️ 画像ソース作成失敗")
            return nil
        }
        
        let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        if let meta = metadata {
            print("📷 メタデータ取得成功: \(meta.keys.count) 項目")
            return meta
        } else {
            print("⚠️ メタデータ取得失敗")
            return nil
        }
        #else
        // macOSの場合はメタデータなしで保存
        print("📷 macOS: メタデータ保存をスキップ")
        return nil
        #endif
    }
    
    private func generateCompositeImageWithMetadata() -> Data {
        // 通常の合成画像を生成
        let compositeImageData = generateFinalCompositeImage()
        
        #if os(iOS)
        // 元画像のメタデータを取得
        guard let originalMetadata = getOriginalImageMetadata(),
              let compositeImage = UIImage(data: compositeImageData) else {
            print("📷 メタデータなしで保存")
            return compositeImageData
        }
        
        // 編集情報を追加したメタデータを作成
        var newMetadata = originalMetadata
        
        // カスタム情報を追加
        if var exifDict = newMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifDict[kCGImagePropertyExifUserComment as String] = "Edited with SwiftUI Photo Editor - Matte:\(matteWidth)px Frame:\(frameWidth)px Ratio:\(frameRatio)"
            newMetadata[kCGImagePropertyExifDictionary as String] = exifDict
        } else {
            let exifDict: [String: Any] = [
                kCGImagePropertyExifUserComment as String: "Edited with SwiftUI Photo Editor - Matte:\(matteWidth)px Frame:\(frameWidth)px Ratio:\(frameRatio)"
            ]
            newMetadata[kCGImagePropertyExifDictionary as String] = exifDict
        }
        
        // 編集日時を追加
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if var tiffDict = newMetadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiffDict[kCGImagePropertyTIFFDateTime as String] = formatter.string(from: Date())
            newMetadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
        } else {
            let tiffDict: [String: Any] = [
                kCGImagePropertyTIFFDateTime as String: formatter.string(from: Date())
            ]
            newMetadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
        }
        
        // メタデータ付きでJPEGに変換（高品質設定）
        guard let cgImage = compositeImage.cgImage else {
            print("⚠️ CGImage変換失敗、元データを返す")
            return compositeImageData
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            print("⚠️ CGImageDestination作成失敗")
            return compositeImageData
        }
        
        // 高品質で保存するためのオプション
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.95
        ]
        
        CGImageDestinationAddImage(destination, cgImage, newMetadata as CFDictionary)
        CGImageDestinationSetProperties(destination, options as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            print("📷 メタデータ付き画像生成成功: \(mutableData.length) bytes")
            return mutableData as Data
        } else {
            print("⚠️ メタデータ付き画像生成失敗")
            return compositeImageData
        }
        #else
        // macOSの場合はそのまま返す
        return compositeImageData
        #endif
    }

    private var imageDisplaySection: some View {
        VStack(spacing: 5) {
            // Text("表示用データ: \(currentImageData.count) bytes")
            //     .font(.caption2)
            //     .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                let availableWidth = geometry.size.width * 0.95
                let availableHeight = geometry.size.height * 0.95
                let targetAspectRatio = parseAspectRatio(frameRatio)
                let (finalImageWidth, finalImageHeight, finalTotalWidth, finalTotalHeight, finalMatteThickness) = calculateImageDimensions(
                    availableWidth: availableWidth,
                    availableHeight: availableHeight,
                    targetAspectRatio: targetAspectRatio,
                    matteWidth: matteWidth,
                    frameWidth: frameWidth
                )
                
                ZStack {
                    // 1. Frame (Outermost, White) - フレームが有効な時は常に表示
                    if isFrameEnabled {
                        Rectangle().fill(Color.white)
                            .frame(width: finalTotalWidth, height: finalTotalHeight)
                    }
                    
                    // 2. Matte (Inside Frame, Black) - 画像の周りに均等に配置
                    if matteWidth > 0 {
                        Rectangle()
                            .fill(Color.black)
                            .frame(
                                width: finalImageWidth + (finalMatteThickness * 2),
                                height: finalImageHeight + (finalMatteThickness * 2)
                            )
                    }
                    
                    // 3. Image (Innermost) - 元画像を常に完全表示
                    if !currentImageData.isEmpty {
                        ZStack {
                            // 元画像を完全表示（変形・クロップなし）
                            if let displayImage = createImageFromCurrentData() {
                                displayImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fit) // 元画像を完全表示
                                    .frame(width: finalImageWidth, height: finalImageHeight)
                                    .scaleEffect(scale)
                                    .rotationEffect(rotation)
                                    .clipped()
                            } else {
                                ImageDisplayView(imageData: currentImageData)
                                    .frame(width: finalImageWidth, height: finalImageHeight)
                                    .scaleEffect(scale)
                                    .rotationEffect(rotation)
                                    .clipped()
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in scale = value }
                                    .onEnded { value in scale = max(0.2, min(value, 5.0)) },
                                RotationGesture()
                                    .onChanged { value in
                                        let degrees = value.degrees
                                        let snapTolerance: Double = 7.5
                                        let snapAngles: [Double] = [0, 90, 180, 270, 360, -90, -180, -270]

                                        for snapAngle in snapAngles {
                                            if abs(degrees.remainder(dividingBy: 360) - snapAngle.remainder(dividingBy: 360)).truncatingRemainder(dividingBy: 360) < snapTolerance {
                                                rotation = .degrees(snapAngle)
                                                return
                                            }
                                        }
                                        rotation = value
                                    }
                            )
                        )
                    } else {
                        Text("画像データなし")
                            .frame(width: finalImageWidth, height: finalImageHeight)
                            .background(Color.gray.opacity(0.2))
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 1, y: 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            // .frame(minHeight: 300, maxHeight: .infinity) // Allow it to grow, but have a min height
            .aspectRatio(1, contentMode: .fit) // Maintain a square area for the GeometryReader, adjust if needed
            .background(Color.clear) // Transparent background for the GeometryReader container
            // .padding(.bottom, 10) // Space before controls
        }
        // .background(Color.white) // Original background for the VStack
        // .cornerRadius(12) // Original corner radius
        // .shadow(radius: 5) // Original shadow
    }
    
    private var controlSection: some View {
        VStack(spacing: 15) {
            if sourceEditedModel != nil {
                Text("保存済み画像を編集中").font(.caption).foregroundColor(.blue)
                    .padding(5).background(Color.blue.opacity(0.1)).cornerRadius(5)
            }
            
            HStack(spacing: 20) { // Reduced spacing
                Button {
                    showMatteControl.toggle()
                    if showMatteControl { showFrameControl = false }
                } label: {
                    Label("マット", systemImage: "square.inset.filled")
                }
                .padding(.horizontal,12).padding(.vertical, 8)
                .background(showMatteControl ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(showMatteControl ? .white : .primary)
                .cornerRadius(8)
                
                Button {
                    showFrameControl.toggle()
                    if showFrameControl { showMatteControl = false }
                } label: {
                    Label("フレーム", systemImage: "photo.artframe")
                }
                .padding(.horizontal,12).padding(.vertical, 8)
                .background(showFrameControl ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(showFrameControl ? .white : .primary)
                .cornerRadius(8)
                
                // フレームオンオフボタン
                Button {
                    isFrameEnabled.toggle()
                    // フレームをオンにした時、最小値チェック
                    if isFrameEnabled {
                        let currentMinFrameWidth = minFrameWidth
                        if frameWidth < currentMinFrameWidth {
                            frameWidth = currentMinFrameWidth
                            print("🔧 フレームオン時に幅を最小値に調整: \(frameWidth)")
                        }
                    }
                } label: {
                    Image(systemName: isFrameEnabled ? "rectangle.fill" : "rectangle")
                        .font(.system(size: 16))
                }
                .padding(.horizontal,10).padding(.vertical, 8)
                .background(isFrameEnabled ? Color.green : Color.gray.opacity(0.3))
                .foregroundColor(isFrameEnabled ? .white : .primary)
                .cornerRadius(8)
            }
            
            if showMatteControl {
                MatteControlView(matteWidth: $matteWidth, maxMatteWidth: maxMatteWidth)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity), removal: .opacity))
                    .onChange(of: matteWidth) { oldValue, newValue in
                        // マット幅が変更された時、フレーム幅が最小値未満にならないよう調整
                        let newMinFrameWidth = minFrameWidth
                        if isFrameEnabled && frameWidth < newMinFrameWidth {
                            frameWidth = newMinFrameWidth
                            print("🔧 フレーム幅を最小値に自動調整: \(frameWidth)")
                        }
                    }
            }
            
            if showFrameControl {
                FrameControlView(
                    frameWidth: $frameWidth,
                    frameRatio: $frameRatio,
                    isFrameEnabled: $isFrameEnabled,
                    minFrameWidth: minFrameWidth,
                    maxFrameWidth: maxFrameWidth,
                    frameRatios: frameRatios
                )
                .transition(.asymmetric(insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showMatteControl)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showFrameControl)
    }
        
    private func saveEditedImage() {
        // SwiftDataには元画像データ（currentImageData）を保存
        var swiftDataSaveSuccess = false
        if let existingModel = sourceEditedModel {
            print("既存モデルを更新: \(existingModel.id)")
            existingModel.imageData = currentImageData // 元画像データを保存
            existingModel.matteWidth = matteWidth
            existingModel.frameWidth = frameWidth
            existingModel.frameRatio = frameRatio
            existingModel.isFrameEnabled = isFrameEnabled
            existingModel.scale = Double(scale)
            existingModel.rotationDegrees = rotation.degrees.remainder(dividingBy: 360)
            existingModel.createdAt = Date()
            swiftDataSaveSuccess = true
        } else {
            print("新規モデルを作成して挿入")
            let newEditedImage = EditedImageModel(
                imageData: currentImageData, // 元画像データを保存
                matteWidth: matteWidth,
                frameWidth: frameWidth,
                frameRatio: frameRatio,
                isFrameEnabled: isFrameEnabled,
                scale: Double(scale),
                rotationDegrees: rotation.degrees.remainder(dividingBy: 360)
            )
            context.insert(newEditedImage)
            swiftDataSaveSuccess = true
        }
        
        do {
            // 明示的に保存前の状態をログ
            print("💾 SwiftData保存開始: 元画像データサイズ=\(currentImageData.count) bytes")
            
            try context.save()
            print("✅ SwiftData保存成功")
            
            // autosaveEnabledの状態を確認
            print("📱 現在のautosaveEnabled: \(context.autosaveEnabled)")
            
            // 保存成功後にデータを検証
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let descriptor = FetchDescriptor<EditedImageModel>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                if let savedImages = try? self.context.fetch(descriptor) {
                    print("📊 保存後検証: 総画像数=\(savedImages.count)")
                    if let latest = savedImages.first {
                        print("📊 最新画像: ID=\(latest.id), データサイズ=\(latest.imageData.count) bytes")
                        print("📊 マット: \(latest.matteWidth), フレーム: \(latest.frameWidth), 比率: \(latest.frameRatio)")
                    }
                } else {
                    print("❌ 保存後検証失敗")
                }
            }
            
            // 追加の安全措置：もう一度明示的に保存
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                do {
                    try self.context.save()
                    print("🔄 追加保存完了")
                } catch {
                    print("❌ 追加保存失敗: \(error)")
                }
            }
            
            // フォトライブラリ用の合成画像を生成
            let finalCompositeImage = generateCompositeImageWithMetadata()
            
            // フォトライブラリに合成画像を保存
            saveToPhotoLibrary(imageData: finalCompositeImage, swiftDataSaveSuccess: swiftDataSaveSuccess)
            
        } catch {
            print("❌ SwiftData 保存エラー: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            if let swiftDataError = error as? any LocalizedError {
                print("❌ Localized description: \(swiftDataError.localizedDescription)")
            }
            saveAlert = .swiftDataError
        }
    }
    
    private func generateFinalCompositeImage() -> Data {
        print("🎨 最終合成画像を生成中...")
        
        // 元画像の実際のサイズを取得
        let originalImageSize = getOriginalImageSize()
        let originalImageAspectRatio = originalImageSize.width / originalImageSize.height
        print("🖼️ 元画像実際のサイズ: \(originalImageSize.width) x \(originalImageSize.height)")
        print("🖼️ 元画像アスペクト比: \(originalImageAspectRatio)")
        
        // 元画像のサイズ（常に完全表示）
        let imageWidth = originalImageSize.width
        let imageHeight = originalImageSize.height
        print("📐 元画像サイズを完全保持: \(imageWidth) x \(imageHeight)")
        
        // マットとフレームのサイズ（元画像サイズに比例）
        let scaleToOriginal = max(originalImageSize.width, originalImageSize.height) / 800.0 // 800は基準サイズ
        let matteThickness = CGFloat(matteWidth) * scaleToOriginal
        let frameThickness = isFrameEnabled ? CGFloat(frameWidth) * scaleToOriginal : 0
        
        // 元画像＋マットのサイズ
        let imageWithMatteWidth = imageWidth + (matteThickness * 2)
        let imageWithMatteHeight = imageHeight + (matteThickness * 2)
        
        let totalWidth: CGFloat
        let totalHeight: CGFloat
        
        if isFrameEnabled {
            // フレーム有効時：指定比率で最終サイズを決定
            let targetAspectRatio = parseAspectRatio(frameRatio)
            let currentAspectRatio = imageWithMatteWidth / imageWithMatteHeight
            
            if targetAspectRatio > currentAspectRatio {
                // より横長に → 高さ基準で幅を調整
                let finalContentHeight = imageWithMatteHeight
                let finalContentWidth = finalContentHeight * targetAspectRatio
                totalWidth = finalContentWidth + (frameThickness * 2)
                totalHeight = finalContentHeight + (frameThickness * 2)
            } else {
                // より縦長に → 幅基準で高さを調整
                let finalContentWidth = imageWithMatteWidth
                let finalContentHeight = finalContentWidth / targetAspectRatio
                totalWidth = finalContentWidth + (frameThickness * 2)
                totalHeight = finalContentHeight + (frameThickness * 2)
            }
            
            print("🎯 フレーム比率 \(frameRatio) で最終サイズ調整: \(totalWidth) x \(totalHeight)")
        } else {
            // フレーム無効時：元画像＋マットのみ
            totalWidth = imageWithMatteWidth
            totalHeight = imageWithMatteHeight
            print("🚫 フレーム無効: 元画像＋マットのみ \(totalWidth) x \(totalHeight)")
        }
        
        print("🎨 保存用合成画像サイズ: \(totalWidth) x \(totalHeight)")
        print("🎨 元画像部分: \(imageWidth) x \(imageHeight)")
        print("🎨 マット厚さ: \(matteThickness)px")
        print("🎨 フレーム厚さ: \(frameThickness)px")
        print("🎨 スケール係数: \(scaleToOriginal)")
        
        // サイズ制限チェック（メモリ効率のため）
        let maxDimension: CGFloat = 8192 // 一般的な制限
        let totalPixels = totalWidth * totalHeight
        let maxPixels: CGFloat = 50_000_000 // 約50MP
        
        if totalWidth > maxDimension || totalHeight > maxDimension {
            print("⚠️ 画像サイズが制限を超過: \(totalWidth) x \(totalHeight) > \(maxDimension)")
            return generateScaledCompositeImage(targetMaxDimension: maxDimension)
        }
        
        if totalPixels > maxPixels {
            print("⚠️ 画像ピクセル数が制限を超過: \(Int(totalPixels)) > \(Int(maxPixels))")
            return generateScaledCompositeImage(targetMaxDimension: sqrt(maxPixels))
        }
        
        // SwiftUIビューで合成画像を作成
        let compositeView = ZStack {
            // 背景（フレーム）- フレームが有効な時のみ表示
            if isFrameEnabled {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: totalWidth, height: totalHeight)
            }
            
            // マット（元画像の周りに均等に配置）
            if matteWidth > 0 {
                Rectangle()
                    .fill(Color.black)
                    .frame(
                        width: imageWidth + (matteThickness * 2),
                        height: imageHeight + (matteThickness * 2)
                    )
            }
            
            // 元画像（常に完全表示、変形なし）
            if let originalImage = createImageFromData(currentImageData) {
                originalImage
                    .resizable()
                    .aspectRatio(contentMode: .fit) // 元画像を完全表示
                    .frame(width: imageWidth, height: imageHeight)
                    .scaleEffect(scale)
                    .rotationEffect(rotation)
                    .clipped()
            } else {
                // フォールバック：画像読み込み失敗時
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: imageWidth, height: imageHeight)
                    .overlay(
                        Text("画像読み込み失敗")
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .background(Color.clear) // 透明背景
        
        print("🎨 SwiftUIビュー作成完了、ImageRendererで変換中...")
        print("🎨 レンダラースケール: 1.0 (高解像度出力)")
        
        // ImageRendererで画像データに変換（スケールを1.0に調整）
        let renderer = ImageRenderer(content: compositeView)
        renderer.scale = 1.0 // メモリ効率とサイズのバランス
        
        #if os(macOS)
        if let nsImage = renderer.nsImage {
            print("✅ NSImage作成成功: \(nsImage.size)")
            if let tiffData = nsImage.tiffRepresentation {
                print("✅ TIFF変換成功: \(tiffData.count) bytes")
                if let bitmapRep = NSBitmapImageRep(data: tiffData) {
                    print("✅ BitmapRep作成成功")
                    if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        print("✅ macOS合成画像生成成功: \(pngData.count) bytes")
                        return pngData
                    } else {
                        print("❌ PNG変換失敗")
                    }
                } else {
                    print("❌ BitmapRep作成失敗")
                }
            } else {
                print("❌ TIFF変換失敗")
            }
        } else {
            print("❌ NSImage作成失敗 - サイズ制限またはメモリ不足の可能性")
        }
        #else
        if let uiImage = renderer.uiImage {
            print("✅ UIImage作成成功: \(uiImage.size)")
            if let pngData = uiImage.pngData() {
                print("✅ iOS合成画像生成成功: \(pngData.count) bytes")
                return pngData
            } else {
                print("❌ PNG変換失敗")
            }
        } else {
            print("❌ UIImage作成失敗 - サイズ制限またはメモリ不足の可能性")
        }
        #endif
        
        print("❌ 通常の合成画像生成失敗、スケール調整版を試行...")
        return generateScaledCompositeImage(targetMaxDimension: 4096)
    }
    
    // スケールダウンしたバージョンの合成画像を生成
    private func generateScaledCompositeImage(targetMaxDimension: CGFloat) -> Data {
        print("🔄 スケールダウン版合成画像を生成中（最大寸法: \(targetMaxDimension)）...")
        
        // 元画像の実際のサイズを取得
        let originalImageSize = getOriginalImageSize()
        let imageWidth = originalImageSize.width
        let imageHeight = originalImageSize.height
        
        // 現在の合成サイズを計算
        let scaleToOriginal = max(originalImageSize.width, originalImageSize.height) / 800.0
        let matteThickness = CGFloat(matteWidth) * scaleToOriginal
        let frameThickness = isFrameEnabled ? CGFloat(frameWidth) * scaleToOriginal : 0
        
        let imageWithMatteWidth = imageWidth + (matteThickness * 2)
        let imageWithMatteHeight = imageHeight + (matteThickness * 2)
        
        let totalWidth: CGFloat
        let totalHeight: CGFloat
        
        if isFrameEnabled {
            let targetAspectRatio = parseAspectRatio(frameRatio)
            let currentAspectRatio = imageWithMatteWidth / imageWithMatteHeight
            
            if targetAspectRatio > currentAspectRatio {
                let finalContentHeight = imageWithMatteHeight
                let finalContentWidth = finalContentHeight * targetAspectRatio
                totalWidth = finalContentWidth + (frameThickness * 2)
                totalHeight = finalContentHeight + (frameThickness * 2)
            } else {
                let finalContentWidth = imageWithMatteWidth
                let finalContentHeight = finalContentWidth / targetAspectRatio
                totalWidth = finalContentWidth + (frameThickness * 2)
                totalHeight = finalContentHeight + (frameThickness * 2)
            }
        } else {
            totalWidth = imageWithMatteWidth
            totalHeight = imageWithMatteHeight
        }
        
        // スケールファクターを計算
        let scaleFactor = min(1.0, targetMaxDimension / max(totalWidth, totalHeight))
        let scaledTotalWidth = totalWidth * scaleFactor
        let scaledTotalHeight = totalHeight * scaleFactor
        let scaledImageWidth = imageWidth * scaleFactor
        let scaledImageHeight = imageHeight * scaleFactor
        let scaledMatteThickness = matteThickness * scaleFactor
        
        print("🔄 スケールファクター: \(scaleFactor)")
        print("🔄 スケール後サイズ: \(scaledTotalWidth) x \(scaledTotalHeight)")
        
        // スケールダウンしたSwiftUIビューを作成
        let scaledCompositeView = ZStack {
            if isFrameEnabled {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: scaledTotalWidth, height: scaledTotalHeight)
            }
            
            if matteWidth > 0 {
                Rectangle()
                    .fill(Color.black)
                    .frame(
                        width: scaledImageWidth + (scaledMatteThickness * 2),
                        height: scaledImageHeight + (scaledMatteThickness * 2)
                    )
            }
            
            if let originalImage = createImageFromData(currentImageData) {
                originalImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: scaledImageWidth, height: scaledImageHeight)
                    .scaleEffect(scale)
                    .rotationEffect(rotation)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .frame(width: scaledImageWidth, height: scaledImageHeight)
                    .overlay(
                        Text("画像読み込み失敗")
                            .foregroundColor(.white)
                            .font(.system(size: min(12, scaledImageWidth / 20)))
                    )
            }
        }
        .frame(width: scaledTotalWidth, height: scaledTotalHeight)
        .background(Color.clear)
        
        // ImageRendererで変換
        let renderer = ImageRenderer(content: scaledCompositeView)
        renderer.scale = 1.0
        
        #if os(macOS)
        if let nsImage = renderer.nsImage,
           let tiffData = nsImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            print("✅ スケールダウン版macOS合成画像生成成功: \(pngData.count) bytes")
            return pngData
        }
        #else
        if let uiImage = renderer.uiImage,
           let pngData = uiImage.pngData() {
            print("✅ スケールダウン版iOS合成画像生成成功: \(pngData.count) bytes")
            return pngData
        }
        #endif
        
        print("❌ スケールダウン版も失敗、元画像を返します")
        return currentImageData
    }
    
    private func createImageFromData(_ data: Data) -> Image? {
        #if os(macOS)
        if let nsImage = NSImage(data: data) {
            return Image(nsImage: nsImage)
        }
        #else
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
    
    private func createImageFromCurrentData() -> Image? {
        #if os(macOS)
        if let nsImage = NSImage(data: currentImageData) {
            return Image(nsImage: nsImage)
        }
        #else
        if let uiImage = UIImage(data: currentImageData) {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
    
    private func saveToPhotoLibrary(imageData: Data, swiftDataSaveSuccess: Bool) {
        // フォトライブラリの権限確認
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.performPhotoLibrarySave(imageData: imageData, swiftDataSaveSuccess: swiftDataSaveSuccess)
                case .denied, .restricted:
                    self.saveAlert = .photoLibraryError
                case .notDetermined:
                    self.saveAlert = .photoLibraryError
                @unknown default:
                    self.saveAlert = .photoLibraryError
                }
            }
        }
    }
    
    private func performPhotoLibrarySave(imageData: Data, swiftDataSaveSuccess: Bool) {
        #if os(iOS)
        guard let uiImage = UIImage(data: imageData) else {
            saveAlert = .photoLibraryError
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("フォトライブラリ保存成功")
                    self.saveAlert = .success
                    self.dismiss()
                } else {
                    print("フォトライブラリ保存失敗: \(error?.localizedDescription ?? "不明なエラー")")
                    if swiftDataSaveSuccess {
                        // SwiftDataは成功したがフォトライブラリが失敗
                        self.dismiss() // とりあえず画面を閉じる
                    }
                    self.saveAlert = .photoLibraryError
                }
            }
        }
        #else
        // macOSの場合はフォトライブラリ保存をスキップ
        if swiftDataSaveSuccess {
            saveAlert = .success
            dismiss()
        }
        #endif
    }
}

// MARK: - MatteControlView
struct MatteControlView: View {
    @Binding var matteWidth: Double
    let maxMatteWidth: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("マット幅: \(String(format: "%.1f", matteWidth))px")
            Slider(value: $matteWidth, in: 0...maxMatteWidth, step: 0.5)
                .accentColor(.black)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - FrameControlView
struct FrameControlView: View {
    @Binding var frameWidth: Double
    @Binding var frameRatio: String
    @Binding var isFrameEnabled: Bool
    let minFrameWidth: Double
    let maxFrameWidth: Double
    let frameRatios: [String]
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("フレーム: \(isFrameEnabled ? "有効" : "無効")")
                    .foregroundColor(isFrameEnabled ? .green : .gray)
                Spacer()
                Toggle("", isOn: $isFrameEnabled)
                    .labelsHidden()
                    .onChange(of: isFrameEnabled) { oldValue, newValue in
                        // フレームをオンにした時、最小値チェック
                        if newValue {
                            if frameWidth < minFrameWidth {
                                frameWidth = minFrameWidth
                                print("🔧 Toggle: フレームオン時に幅を最小値に調整: \(frameWidth)")
                            }
                        }
                    }
            }
            
            if isFrameEnabled {
                VStack {
                    HStack {
                        Text("フレーム幅: \(Int(frameWidth))")
                        Spacer()
                        if minFrameWidth > 0 {
                            Text("最小: \(Int(minFrameWidth))")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    Slider(value: $frameWidth, in: minFrameWidth...maxFrameWidth, step: 1)
                        .onChange(of: minFrameWidth) { oldValue, newValue in
                            // 最小値が変更された時、現在の値が最小値未満の場合は調整
                            if frameWidth < newValue {
                                frameWidth = newValue
                            }
                        }
                }
                
                Divider().padding(.vertical, 5)
                
                HStack {
                    Text("フレーム比率:")
                    Spacer()
                    Picker("比率", selection: $frameRatio) {
                        ForEach(frameRatios, id: \.self) { ratio in
                            Text(ratio).tag(ratio)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(minWidth: 100)
                    
                    // 比率逆転ボタン
                    Button(action: {
                        frameRatio = reverseAspectRatio(frameRatio)
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("比率を逆転 (例: 2:3 → 3:2)")
                }
                
                Text("※フレーム有効時は指定比率で最終出力サイズが決定されます。元画像は常に完全表示されます。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("フレームを有効にしてください")
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func reverseAspectRatio(_ ratio: String) -> String {
        let components = ratio.split(separator: ":")
        if components.count == 2,
           let widthComponent = Double(components[0]),
           let heightComponent = Double(components[1]),
           heightComponent != 0 {
            return "\(Int(heightComponent)):\(Int(widthComponent))"
        }
        print("アスペクト比逆転失敗: \(ratio), デフォルト1:1を使用")
        return "1:1"
    }
}