//
//  sampleApp.swift
//  sample
//
//  Created by Takuya M on 2025/06/03.
//

import SwiftUI
import SwiftData

@main
struct sampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(createModelContainer())
        }
    }
    
    private func createModelContainer() -> ModelContainer {
        // まず、古いキャッシュやデータベースをクリアする（開発中のみ）
        #if DEBUG
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let appSupportURL = urls.first {
            let dataURL = appSupportURL.appendingPathComponent("default.store")
            if FileManager.default.fileExists(atPath: dataURL.path) {
                do {
                    try FileManager.default.removeItem(at: dataURL)
                    print("🗑️ 古いデータベースファイルを削除しました")
                } catch {
                    print("⚠️ 古いデータベースファイル削除失敗: \(error)")
                }
            }
        }
        #endif
        
        // 設定1: 通常の永続化コンテナを試行
        do {
            let configuration = ModelConfiguration(
                schema: Schema([EditedImageModel.self]),
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            let container = try ModelContainer(for: EditedImageModel.self, configurations: configuration)
            
            // メインコンテキストのautosaveEnabledを確認・設定
            let mainContext = container.mainContext
            print("📱 メインコンテキストのautosaveEnabled: \(mainContext.autosaveEnabled)")
            
            mainContext.autosaveEnabled = true
            print("📱 autosaveEnabledをtrueに設定しました")
            
            // データベースの場所をログ出力
            if let url = container.configurations.first?.url {
                print("📁 SwiftData保存場所: \(url)")
            }
            
            print("✅ SwiftData永続化コンテナ初期化成功")
            return container
        } catch {
            print("❌ 永続化ModelContainer作成エラー: \(error)")
            print("❌ Error details: \(error)")
        }
        
        // 設定2: カスタム場所での永続化を試行
        do {
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            if let documentsURL = urls.first {
                let customURL = documentsURL.appendingPathComponent("EditedImages.sqlite")
                print("🔄 カスタム場所での永続化試行: \(customURL)")
                
                let customConfig = ModelConfiguration(
                    schema: Schema([EditedImageModel.self]),
                    url: customURL,
                    allowsSave: true
                )
                
                let container = try ModelContainer(for: EditedImageModel.self, configurations: customConfig)
                container.mainContext.autosaveEnabled = true
                print("✅ カスタム場所での永続化成功")
                return container
            }
        } catch {
            print("❌ カスタム場所永続化も失敗: \(error)")
        }
        
        // 設定3: シンプルな永続化コンテナ
        do {
            print("🔄 シンプル永続化コンテナで試行...")
            let container = try ModelContainer(for: EditedImageModel.self)
            container.mainContext.autosaveEnabled = true
            print("✅ シンプル永続化コンテナ作成成功")
            return container
        } catch {
            print("❌ シンプル永続化コンテナも失敗: \(error)")
        }
        
        // フォールバック：インメモリーコンテナを使用
        do {
            print("🔄 最終フォールバック：インメモリーコンテナ...")
            let fallbackContainer = try ModelContainer(for: EditedImageModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            fallbackContainer.mainContext.autosaveEnabled = true
            print("✅ インメモリーコンテナ作成成功")
            return fallbackContainer
        } catch {
            print("❌ インメモリーコンテナも失敗: \(error)")
            // 最後の手段：基本的なコンテナ
            return try! ModelContainer(for: EditedImageModel.self)
        }
    }
}
