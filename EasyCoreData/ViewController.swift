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
            
            context.objects(entity: Entity.self, predicate: NSPredicate(format: "name like %@", argumentArray: ["NM:774"])).map { (object: Entity)->Void in
                println(object.name)
            }
        })
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

