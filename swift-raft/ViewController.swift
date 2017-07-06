//
//  ViewController.swift
//  swift-raft
//
//  Created by Frank the Tank on 6/28/17.
//  Copyright © 2017 Frank the Tank. All rights reserved.
//

import UIKit
import Stevia

class ViewController: UIViewController {
    var logTextView = UITextView()
    var inputTextField = UITextField()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Swift Raft"
        logTextView.text = "log log log"
        inputTextField.text = "some input"
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        logTextView.height(400)
        view.sv([logTextView, inputTextField])
        view.layout(
            0,
            |-0-logTextView-0-|,
            10,
            |-0-inputTextField-0-|,
            0
        )
    }

}
