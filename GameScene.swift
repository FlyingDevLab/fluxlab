//
//  fluxlabApp.swift
//  fluxlab
//
//  Created by FlyingDevLab on 2026/03/03.
//

import SpriteKit
import CoreMotion

class GameScene: SKScene {
    let motionManager = CMMotionManager() // 加速度センサー（スマホの傾き）
    var faucet: SKLabelNode!              // 初期配置の蛇口
    var drain: SKLabelNode!               // 渦巻き（排水口）
    var selectedNode: SKNode?             // 選択中のパーツ
    
    var initialTouchAngle: CGFloat = 0    // 回転用：開始角度
    var initialNodeRotation: CGFloat = 0 // 回転用：パーツの初期角度

    override func didMove(to view: SKView) {
        self.backgroundColor = .black
        
        // 画面の端に物理的な壁を作り、パーツが落ちないようにする
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        
        setupStaticNodes()     // 蛇口・渦巻きの初期配置
        startGravityUpdates()  // 重力シミュレーション開始
        startWaterFlow()       // 水の生成ループ開始
    }
    
    func setupStaticNodes() {
        // 🚰 初期蛇口
        faucet = SKLabelNode(text: "🚰")
        faucet.position = CGPoint(x: size.width / 2, y: size.height - 120)
        faucet.fontSize = 50
        faucet.name = "draggable_faucet"
        faucet.physicsBody = SKPhysicsBody(circleOfRadius: 25)
        faucet.physicsBody?.isDynamic = false
        addChild(faucet)
        
        // 🌀 渦巻き（削除・吸い込み地点）
        drain = SKLabelNode(text: "🌀")
        drain.position = CGPoint(x: size.width / 2, y: 150)
        drain.fontSize = 60
        drain.name = "draggable_drain"
        drain.physicsBody = SKPhysicsBody(circleOfRadius: 30)
        drain.physicsBody?.isDynamic = false
        addChild(drain)
    }

    // 水の粒を生成（全蛇口から共通で呼び出し）
    func createWaterDrop(from node: SKNode) {
        let pRadius: CGFloat = 8
        let vRadius: CGFloat = 12 // 物理半径より大きくして重なりを表現
        
        let water = SKShapeNode(circleOfRadius: vRadius)
        water.fillColor = .cyan.withAlphaComponent(0.9)
        water.strokeColor = .clear
        water.position = CGPoint(x: node.position.x, y: node.position.y - 35)
        
        let body = SKPhysicsBody(circleOfRadius: pRadius)
        body.friction = 0.01
        body.restitution = 0.1
        water.physicsBody = body
        water.name = "water"
        addChild(water)
    }

    // 【修正】確率に傾斜をつけたランダム生成
    func spawnRandomObject(at pos: CGPoint) {
        // 0〜6の乱数を生成（合計7つの枠）
        // 0,1,2,3 -> 棒 (4/7)
        // 4,5     -> 水車 (2/7)
        // 6       -> 蛇口 (1/7)
        let roll = Int.random(in: 0...6)
        
        if roll <= 3 {
            // --- 棒の生成 (一番多い) ---
            let bar = SKSpriteNode(color: .lightGray, size: CGSize(width: 150, height: 20))
            bar.position = pos
            bar.name = "draggable_bar"
            bar.physicsBody = SKPhysicsBody(rectangleOf: bar.size)
            bar.physicsBody?.isDynamic = false
            addChild(bar)
            
        } else if roll <= 5 {
            // --- 水車の生成 (棒の半分) ---
            let wheel = SKNode()
            wheel.position = pos
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
            
        } else {
            // --- 蛇口の生成 (水車の半分) ---
            let newFaucet = SKLabelNode(text: "🚰")
            newFaucet.position = pos
            newFaucet.fontSize = 50
            newFaucet.name = "draggable_faucet"
            newFaucet.physicsBody = SKPhysicsBody(circleOfRadius: 25)
            newFaucet.physicsBody?.isDynamic = false
            addChild(newFaucet)
        }
    }

    // 水車などの回転軸（ピン）を設定
    func setupJoint(for node: SKNode) {
        removeAnchor(for: node)
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

    // 回転軸を安全に削除
    func removeAnchor(for node: SKNode) {
        let anchorName = "anchor_\(node.hash)"
        enumerateChildNodes(withName: anchorName) { a, _ in
            a.removeFromParent()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodesAtPoint = nodes(at: loc)
        
        // 既存パーツに触れた場合は移動、何もない場所なら生成
        if let target = nodesAtPoint.first(where: { $0.name?.contains("draggable") == true }) {
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
        } else {
            spawnRandomObject(at: loc)
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
            
            // 渦巻き（🌀）に重なったら削除
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

    override func update(_ currentTime: TimeInterval) {
        // 渦巻きによる水の吸い込み判定
        if let dNode = childNode(withName: "draggable_drain") {
            enumerateChildNodes(withName: "water") { w, _ in
                if hypot(w.position.x - dNode.position.x, w.position.y - dNode.position.y) < 40 {
                    w.removeFromParent()
                }
            }
        }
    }

    // デバイスの傾きを物理重力に反映
    func startGravityUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.05
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let d = data else { return }
                self.physicsWorld.gravity = CGVector(dx: d.acceleration.x * 15, dy: d.acceleration.y * 15)
            }
        }
    }

    // すべての蛇口から水を出すループ
    func startWaterFlow() {
        let seq = SKAction.sequence([
            .wait(forDuration: 0.1),
            .run { [weak self] in
                guard let self = self else { return }
                self.enumerateChildNodes(withName: "draggable_faucet") { node, _ in
                    self.createWaterDrop(from: node)
                }
            }
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
