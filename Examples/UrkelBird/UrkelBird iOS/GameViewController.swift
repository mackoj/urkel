//
//  GameViewController.swift
//  UrkelBird iOS
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

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
