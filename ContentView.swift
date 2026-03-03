//
//  fluxlabApp.swift
//  fluxlab
//
//  Created by FlyingDevLab on 2026/03/03.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    // 画面サイズに合わせたGameSceneの初期化
    @State private var scene: GameScene = {
        let scene = GameScene()
        scene.size = CGSize(width: 375, height: 812)
        scene.scaleMode = .resizeFill
        return scene
    }()
    //アプリの状態（バックグラウンド移行など）を検知
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            // ゲーム画面を全画面表示
            SpriteView(scene: scene)
                .ignoresSafeArea()
        }
        // アプリの状態変化に合わせて物理シミュレーションを一時停止/再開
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active: scene.resumeAllProcesses()
            case .background, .inactive: scene.stopAllProcesses()
            @unknown default: break
            }
        }
    }
}
