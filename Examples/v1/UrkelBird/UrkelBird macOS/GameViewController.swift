//
//  GameViewController.swift
//  UrkelBird macOS
//
//  Created by Jeffrey MACKO on 21/03/2026.
//

import Cocoa
import SpriteKit
import GameplayKit
import UrkelBird

class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let scene = UrkelBirdGameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill

        let skView = self.view as! SKView
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

}
