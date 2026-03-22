//
//  GameViewController.swift
//  UrkelBird tvOS
//
//  Created by Jeffrey MACKO on 21/03/2026.
//

import UIKit
import SpriteKit
import GameplayKit
import UrkelBird

class GameViewController: UIViewController {
    
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
