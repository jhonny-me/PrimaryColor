//
//  ViewController.swift
//  PrimaryColor
//
//  Created by Johnny Gu on 08/03/2017.
//  Copyright © 2017 Johnny Gu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!

    let imageNames = ["berlin.jpg","club.jpg","glotze.jpg", "Wechat.png"]//,"markt.jpg","melone.jpg","strand.jpg"]
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return imageNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ProcessTableViewCell.identifier, for: indexPath) as? ProcessTableViewCell else { return UITableViewCell() }
        cell.processedImageView.image = UIImage(named: imageNames[indexPath.row])
        cell.startRecoginize()
        return cell
    }
}

class ProcessTableViewCell: UITableViewCell {
    @IBOutlet weak var processedImageView: UIImageView!
    @IBOutlet weak var mainColorImageView: UIImageView!
    
    static let identifier = "ProcessTableViewCell"
    func startRecoginize() {
        PCProcesser().extractMainColor(from: processedImageView.image!) { (color) in
            self.mainColorImageView.backgroundColor = color
            let layer = CAGradientLayer()
            layer.frame = CGRect(origin: CGPoint.zero, size: self.processedImageView.frame.size)
            layer.colors = [color.cgColor, UIColor.clear.cgColor]
            layer.startPoint = CGPoint(x: 0, y: 0)
            layer.endPoint = CGPoint(x: 1, y: 0)
            self.processedImageView.layer.addSublayer(layer)
        }
    }
}
