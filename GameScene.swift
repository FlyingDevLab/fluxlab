//
//  fluxlabApp.swift
//  fluxlab
//
//  Created by FlyingDevLab on 2026/03/03.
//

import SpriteKit
import CoreMotion

class GameScene: SKScene {
    let motionManager = CMMotionManager() // 加速度センサーの管理
    var faucet: SKLabelNode!              // 蛇口（🚰）
    var drain: SKLabelNode!               // 排水口（🌀）
    var selectedNode: SKNode?             // ドラッグ中のオブジェクト
    
    // 回転操作用の初期値
    var initialTouchAngle: CGFloat = 0
    var initialNodeRotation: CGFloat = 0

    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        
        // 画面の縁に物理的な壁を設定
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        
        setupStaticNodes()     // 常設パーツの配置
        setupInteractiveUI()   // 操作ボタンなどの配置
        startGravityUpdates()  // 重力センサー開始
        startWaterFlow()       // 水の生成開始
    }
    
    // --- 初期パーツ配置 ---
    func setupStaticNodes() {
        // 蛇口：水の発生源
        faucet = SKLabelNode(text: "🚰")
        faucet.position = CGPoint(x: size.width / 2, y: size.height - 120)
        faucet.fontSize = 50
        faucet.name = "draggable_faucet"
        faucet.physicsBody = SKPhysicsBody(circleOfRadius: 25)
        faucet.physicsBody?.isDynamic = false
        addChild(faucet)
        
        // 排水口：水を消す地点。移動はできるが自身は消滅しない。
        drain = SKLabelNode(text: "🌀")
        drain.position = CGPoint(x: size.width / 2, y: 150)
        drain.fontSize = 60
        drain.name = "draggable_drain"
        drain.physicsBody = SKPhysicsBody(circleOfRadius: 30)
        drain.physicsBody?.isDynamic = false
        addChild(drain)
    }

    func setupInteractiveUI() {
        // 説明用テキスト
        let infoLabel = SKLabelNode(text: "スマホを傾けて水を流そう！ 🌀に運んで削除")
        infoLabel.fontSize = 14
        infoLabel.position = CGPoint(x: size.width / 2, y: 50)
        infoLabel.name = "draggable_info"
        infoLabel.physicsBody = SKPhysicsBody(rectangleOf: infoLabel.frame.size)
        infoLabel.physicsBody?.isDynamic = false
        addChild(infoLabel)

        // 生成ボタン（ー）
        let minusBtn = SKShapeNode(rectOf: CGSize(width: 80, height: 50), cornerRadius: 10)
        minusBtn.fillColor = .blue.withAlphaComponent(0.8)
        minusBtn.position = CGPoint(x: size.width / 2 - 60, y: size.height - 200)
        minusBtn.name = "btn_bar"
        let minusLabel = SKLabelNode(text: "ー")
        minusLabel.verticalAlignmentMode = .center
        minusBtn.addChild(minusLabel)
        minusBtn.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 80, height: 50))
        minusBtn.physicsBody?.isDynamic = false
        addChild(minusBtn)

        // 生成ボタン（＋）
        let plusBtn = SKShapeNode(rectOf: CGSize(width: 80, height: 50), cornerRadius: 10)
        plusBtn.fillColor = .orange.withAlphaComponent(0.8)
        plusBtn.position = CGPoint(x: size.width / 2 + 60, y: size.height - 200)
        plusBtn.name = "btn_wheel"
        let plusLabel = SKLabelNode(text: "＋")
        plusLabel.verticalAlignmentMode = .center
        plusBtn.addChild(plusLabel)
        plusBtn.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 80, height: 50))
        plusBtn.physicsBody?.isDynamic = false
        addChild(plusBtn)
    }

    // --- 水の生成（ユーザー案採用：物理判定より描画を大きくして重なりを表現） ---
    func createWaterDrop() {
        guard let fNode = childNode(withName: "draggable_faucet") else { return }
        
        let pRadius: CGFloat = 8  // 物理的な当たり判定
        let vRadius: CGFloat = 12 // 見た目の大きさ（少し大きくして重なりを作る）
        
        let water = SKShapeNode(circleOfRadius: vRadius)
        water.fillColor = .cyan.withAlphaComponent(1.0)
        water.strokeColor = .clear
        water.position = CGPoint(x: fNode.position.x, y: fNode.position.y - 35)
        
        let body = SKPhysicsBody(circleOfRadius: pRadius)
        body.friction = 0.01
        body.restitution = 0.1
        water.physicsBody = body
        water.name = "water"
        addChild(water)
    }

    // --- 物理オブジェクト（棒・水車）の追加 ---
    func addBar() {
        let bar = SKSpriteNode(color: .lightGray, size: CGSize(width: 150, height: 20))
        bar.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bar.name = "draggable_bar"
        bar.physicsBody = SKPhysicsBody(rectangleOf: bar.size)
        bar.physicsBody?.isDynamic = false
        addChild(bar)
    }

    func addWaterWheel() {
        let wheel = SKNode()
        wheel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        wheel.name = "draggable_wheel"
        let bSize = CGSize(width: 140, height: 15)
        for i in 0..<2 {
            let b = SKShapeNode(rectOf: bSize, cornerRadius: 4)
            b.fillColor = .orange
            b.zRotation = (CGFloat.pi / 2) * CGFloat(i)
            wheel.addChild(b)
        }
        wheel.physicsBody = SKPhysicsBody(bodies: [
            SKPhysicsBody(rectangleOf: bSize),
            SKPhysicsBody(rectangleOf: CGSize(width: bSize.height, height: bSize.width))
        ])
        wheel.physicsBody?.isDynamic = true
        addChild(wheel)
        setupJoint(for: wheel)
    }

    // --- クラッシュ防止用：ジョイントとアンカーの安全な管理 ---
    func setupJoint(for node: SKNode) {
        removeAnchor(for: node) // 二重生成防止
        
        let anchor = SKNode()
        anchor.position = node.position
        anchor.name = "anchor_\(node.hash)"
        let aBody = SKPhysicsBody(circleOfRadius: 1)
        aBody.isDynamic = false
        anchor.physicsBody = aBody
        addChild(anchor)
        
        if let nBody = node.physicsBody, let aBody = anchor.physicsBody {
            let pin = SKPhysicsJointPin.joint(withBodyA: aBody, bodyB: nBody, anchor: node.position)
            self.physicsWorld.add(pin)
        }
    }

    func removeAnchor(for node: SKNode) {
        let anchorName = "anchor_\(node.hash)"
        enumerateChildNodes(withName: anchorName) { a, _ in
            a.removeFromParent()
        }
    }

    // --- タッチ操作制御 ---
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodesAtPoint = nodes(at: loc)
        
        if let target = nodesAtPoint.first(where: { $0.name?.contains("draggable") == true || $0.name?.contains("btn") == true }) {
            if target.name == "btn_bar" { addBar() }
            if target.name == "btn_wheel" { addWaterWheel() }
            
            selectedNode = target
            selectedNode?.physicsBody?.isDynamic = false
            
            let all = event?.allTouches ?? touches
            if all.count == 2 {
                let t = Array(all)
                let p1 = t[0].location(in: self)
                let p2 = t[1].location(in: self)
                initialTouchAngle = atan2(p2.y - p1.y, p2.x - p1.x)
                initialNodeRotation = target.zRotation
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = selectedNode else { return }
        let all = event?.allTouches ?? touches
        let t = Array(all)
        
        if t.count == 1 {
            node.position = t[0].location(in: self)
        } else if t.count == 2 {
            let p1 = t[0].location(in: self)
            let p2 = t[1].location(in: self)
            let angle = atan2(p2.y - p1.y, p2.x - p1.x)
            node.zRotation = initialNodeRotation + (angle - initialTouchAngle)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = selectedNode else { return }
        
        if let dNode = childNode(withName: "draggable_drain") {
            let dist = hypot(node.position.x - dNode.position.x, node.position.y - dNode.position.y)
            
            // 🌀の近くで離したとき、🌀自体でなければ削除
            if dist < 65 && node.name != "draggable_drain" {
                removeAnchor(for: node)
                node.removeFromParent()
            } else {
                if node.name == "draggable_wheel" {
                    node.physicsBody?.isDynamic = true
                    setupJoint(for: node)
                } else {
                    node.physicsBody?.isDynamic = false
                }
            }
        }
        selectedNode = nil
    }

    // --- 毎フレームの更新処理（水の吸い込み判定） ---
    override func update(_ currentTime: TimeInterval) {
        if let dNode = childNode(withName: "draggable_drain") {
            enumerateChildNodes(withName: "water") { w, _ in
                if hypot(w.position.x - dNode.position.x, w.position.y - dNode.position.y) < 40 {
                    w.removeFromParent()
                }
            }
        }
    }

    // --- 加速度センサー・生成管理 ---
    func startGravityUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.05
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let d = data else { return }
                self.physicsWorld.gravity = CGVector(dx: d.acceleration.x * 15, dy: d.acceleration.y * 15)
            }
        }
    }

    func startWaterFlow() {
        let seq = SKAction.sequence([
            .wait(forDuration: 0.1),
            .run { [weak self] in self?.createWaterDrop() }
        ])
        run(.repeatForever(seq))
    }

    func stopAllProcesses() {
        self.isPaused = true
        motionManager.stopAccelerometerUpdates()
    }

    func resumeAllProcesses() {
        self.isPaused = false
        startGravityUpdates()
    }
}
