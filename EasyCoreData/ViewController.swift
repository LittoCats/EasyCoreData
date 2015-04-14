//
//  ViewController.swift
//  EasyCoreData
//
//  Created by 程巍巍 on 3/18/15.
//  Copyright (c) 2015 Littocats. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            var context = EasyCoreData.context(momd: "Model")
            println("\n\(context)\n\(context.parentContext)\n\(context.parentContext?.parentContext)\n")
            
//            var instance = context.insert(entity: Entity.self)
            
//            var count = 1000
//            while count-- > 0{
//                context.insert(entity: Entity.self, content: ["name": "test_\(count)", "address": "address_\(count)"])
//                if count % 50 == 0 {context.save(nil)}
//            }
//            context.save(nil)
            context.objects(entity: Entity.self).map { (object: Entity)->Void in
                println("\(object.name)  \(object.address)")
            }
        })
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

