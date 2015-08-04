//
//  GameScene.swift
//  Swifty Ninja
//
//  Created by Mac Bellingrath on 8/4/15.
//  Copyright (c) 2015 Mac Bellingrath. All rights reserved.
//

import SpriteKit
import AVFoundation
import UIKit

enum SequenceType: Int {
    case OneNoBomb, One, TwoWithOneBomb, Two, Three, Four, Chain, FastChain
}
enum ForceBomb {
    case Never, Always, Default
}

class GameScene: SKScene {
    var gameScore: SKLabelNode!
    var activeSlicePoints = [CGPoint]()
    var activeEnemies = [SKSpriteNode]()
    var swooshSoundActive = false
    var bombSoundEffect: AVAudioPlayer!
    var score: Int = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    var livesImages = [SKSpriteNode]()
    var lives = 3
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    var popupTime = 0.9
    var sequence: [SequenceType]!
    var sequencePosition = 0
    var chainDelay = 3.0
    var nextSequenceQueued = true
    var gameEnded = false
    
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .Replace
        addChild(background)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        physicsWorld.speed = 0.85
        createScore()
        createLives()
        createSlices()
        
        sequence = [.OneNoBomb, .OneNoBomb, .TwoWithOneBomb, .TwoWithOneBomb, .Three, .One, .Chain]
        
        for _ in 0 ... 1000 {
            let nextSequence = SequenceType(rawValue: RandomInt(2, max: 7))!
            sequence.append(nextSequence)
        }
        
        runAfterDelay(2) { [unowned self] in
            self.tossEnemies()
        }
        
        }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
       /* Called when a touch begins */
        super.touchesBegan(touches, withEvent: event)
        
        //1
        activeSlicePoints.removeAll(keepCapacity: true)
        
        //2
        for touch in touches {

            let location = touch.locationInNode(self)
            activeSlicePoints.append(location)
        //3
            redrawActiveSlice()
        //4 
            activeSliceBG.removeAllActions()
            activeSliceFG.removeAllActions()
        //5 
            activeSliceBG.alpha = 1
            activeSliceFG.alpha = 1
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if gameEnded {
            return
        }
        for touch in touches{
            let location = touch.locationInNode(self)
            activeSlicePoints.append(location)
            redrawActiveSlice()
            
            let nodes = nodesAtPoint(location) as [SKNode]
            
            for node in nodes {
                if node.name == "enemy" {
                    // 1
                    let explosionPath = NSBundle.mainBundle().pathForResource("sliceHitEnemy", ofType: "sks")!
                    let emitter = NSKeyedUnarchiver.unarchiveObjectWithFile(explosionPath) as! SKEmitterNode
                    emitter.position = node.position
                    addChild(emitter)
                    
                    // 2
                    node.name = ""
                    
                    // 3
                    node.physicsBody!.dynamic = false
                    
                    // 4
                    let scaleOut = SKAction.scaleTo(0.001, duration:0.2)
                    let fadeOut = SKAction.fadeOutWithDuration(0.2)
                    let group = SKAction.group([scaleOut, fadeOut])
                    
                    // 5
                    let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                    node.runAction(seq)
                    
                    // 6
                    ++score
                    
                    // 7
                    let index = activeEnemies.indexOf(node as! SKSpriteNode)!
                    activeEnemies.removeAtIndex(index)
                    
                    // 8
                    runAction(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                } else if node.name == "bomb" {
                    let explosionPath = NSBundle.mainBundle().pathForResource("sliceHitBomb", ofType: "sks")!
                    let emitter = NSKeyedUnarchiver.unarchiveObjectWithFile(explosionPath) as! SKEmitterNode
                    emitter.position = node.parent!.position
                    addChild(emitter)
                    
                    node.name = ""
                    node.parent!.physicsBody!.dynamic = false
                    
                    let scaleOut = SKAction.scaleTo(0.001, duration:0.2)
                    let fadeOut = SKAction.fadeOutWithDuration(0.2)
                    let group = SKAction.group([scaleOut, fadeOut])
                    
                    let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                    
                    node.parent!.runAction(seq)
                    
                    let index = activeEnemies.indexOf(node.parent as! SKSpriteNode)!
                    activeEnemies.removeAtIndex(index)
                    
                    runAction(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                    endGame(true)
                }
            }
            
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        activeSliceBG.runAction(SKAction.fadeOutWithDuration(0.25))
        activeSliceFG.runAction(SKAction.fadeOutWithDuration(0.25))
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        touchesEnded(touches!, withEvent: event)
    }
   
    override func update(currentTime: CFTimeInterval) {
        var bombCount = 0
        
        for node in activeEnemies {
            if node.name == "bombContainer" {
                ++bombCount
                break
            }
        }
        
        if bombCount == 0 {
            // no bombs – stop the fuse sound!
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
        }
        
        if activeEnemies.count > 0 {
            for node in activeEnemies {
                if node.position.y < -140 {
                    node.removeAllActions()
                    
                    if node.name == "enemy" {
                        node.name = ""
                        subtractLife()
                        
                        node.removeFromParent()
                        
                        if let index = activeEnemies.indexOf(node) {
                            activeEnemies.removeAtIndex(index)
                        }
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        
                        if let index = activeEnemies.indexOf(node) {
                            activeEnemies.removeAtIndex(index)
                        }
                    }
                }
            }
        } else {
            if !nextSequenceQueued {
                runAfterDelay(popupTime) { [unowned self] in
                    self.tossEnemies()
                }
                
                nextSequenceQueued = true
            }
        }
    }
    
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.text = "Score: 0"
        gameScore.horizontalAlignmentMode = .Left
        gameScore.fontSize = 48
        addChild(gameScore)
        gameScore.position = CGPoint(x: 8, y: 8)
    }
    func createLives() {
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    func createSlices() {
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 2
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.whiteColor()
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
   
    func createEnemy(forceBomb: ForceBomb = .Default) {
    var enemy: SKSpriteNode
    
    var enemyType = RandomInt(0, max: 6)
    
    if forceBomb == .Never {
    enemyType = 1
    } else if forceBomb == .Always {
    enemyType = 0
    }
    
    if enemyType == 0 {
        // 1
        enemy = SKSpriteNode()
        enemy.zPosition = 1
        enemy.name = "bombContainer"
        
        // 2
        let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
        bombImage.name = "bomb"
        enemy.addChild(bombImage)
        
        // 3
        if bombSoundEffect != nil {
            bombSoundEffect.stop()
            bombSoundEffect = nil
        }
        
        // 4
        let path = NSBundle.mainBundle().pathForResource("sliceBombFuse.caf", ofType:nil)!
        let url = NSURL(fileURLWithPath: path)
        let sound = try! AVAudioPlayer(contentsOfURL: url, fileTypeHint: nil)
        bombSoundEffect = sound
        sound.play()
        
        // 5
        let particlePath = NSBundle.mainBundle().pathForResource("sliceFuse", ofType: "sks")!
        let emitter = NSKeyedUnarchiver.unarchiveObjectWithFile(particlePath) as! SKEmitterNode
        emitter.position = CGPoint(x: 76, y: 64)
        enemy.addChild(emitter)
    } else {
    enemy = SKSpriteNode(imageNamed: "penguin")
    runAction(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
    enemy.name = "enemy"
        }
    
        // 1
        let randomPosition = CGPoint(x: RandomInt(64, max: 960), y: -128)
        enemy.position = randomPosition
        
        // 2
        let  randomAngularVelocity = CGFloat(RandomInt(-6, max: 6)) / 2.0
        var randomXVelocity = 0
        
        // 3
        if randomPosition.x < 256 {
            randomXVelocity = RandomInt(8, max: 15)
        } else if randomPosition.x < 512 {
            randomXVelocity = RandomInt(3, max: 5)
        } else if randomPosition.x < 768 {
            randomXVelocity = -RandomInt(3, max: 5)
        } else {
            randomXVelocity = -RandomInt(8, max: 15)
        }
        
        // 4
        let randomYVelocity = RandomInt(24, max: 32)
        
        // 5
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody!.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody!.angularVelocity = randomAngularVelocity
        enemy.physicsBody!.collisionBitMask = 0
        
  
    
    addChild(enemy)
    activeEnemies.append(enemy)
    }
    
    
    func redrawActiveSlice() {
        // 1
        if activeSlicePoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        // 2
        while activeSlicePoints.count > 12 {
            activeSlicePoints.removeAtIndex(0)
        }
        
        // 3
        let path = UIBezierPath()
        path.moveToPoint(activeSlicePoints[0])
        
        for var i = 1; i < activeSlicePoints.count; ++i {
            path.addLineToPoint(activeSlicePoints[i])
        }
        
        // 4
        activeSliceBG.path = path.CGPath
        activeSliceFG.path = path.CGPath
}
    func playSwooshSound() {
        swooshSoundActive = true
        
        let randomNumber = RandomInt(1, max: 3)
        let soundName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        runAction(swooshSound) { [unowned self] in
            self.swooshSoundActive = false
        }
    }
    func tossEnemies() {
        if gameEnded {
            return
        }
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
        case .OneNoBomb:
            createEnemy(.Never)
            
        case .One:
            createEnemy()
            
        case .TwoWithOneBomb:
            createEnemy(.Never)
            createEnemy(.Always)
            
        case .Two:
            createEnemy()
            createEnemy()
            
        case .Three:
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .Four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .Chain:
            createEnemy()
            
            runAfterDelay(chainDelay / 5.0) { [unowned self] in self.createEnemy() }
            runAfterDelay(chainDelay / 5.0 * 2) { [unowned self] in self.createEnemy() }
            runAfterDelay(chainDelay / 5.0 * 3) { [unowned self] in self.createEnemy() }
            runAfterDelay(chainDelay / 5.0 * 4) { [unowned self] in self.createEnemy() }
            
        case .FastChain:
            createEnemy()
            
            runAfterDelay(chainDelay / 10.0) { [unowned self] in self.createEnemy() }
            runAfterDelay(chainDelay / 10.0 * 2) { [unowned self] in self.createEnemy() }
            runAfterDelay(chainDelay / 10.0 * 3) { [unowned self] in self.createEnemy() }
            runAfterDelay(chainDelay / 10.0 * 4) { [unowned self] in self.createEnemy() }
        }
        
        
        ++sequencePosition
        
        nextSequenceQueued = false
    }
    func subtractLife() {
        --lives
        
        runAction(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(false)
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        
        life.xScale = 1.3
        life.yScale = 1.3
        life.runAction(SKAction.scaleTo(1, duration:0.1))
    }
    func endGame(triggeredByBomb: Bool) {
        if gameEnded {
            return
        }
        
        gameEnded = true
        physicsWorld.speed = 0
        userInteractionEnabled = false
        
        if bombSoundEffect != nil {
            bombSoundEffect.stop()
            bombSoundEffect = nil
        }
        
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
    }
}