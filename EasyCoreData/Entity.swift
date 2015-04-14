//
//  Entity.swift
//  EasyCoreData
//
//  Created by 程巍巍 on 3/18/15.
//  Copyright (c) 2015 Littocats. All rights reserved.
//

import Foundation
import CoreData

@objc(Entity)
class Entity: NSManagedObject, NSManagedObjectJSONProtocol {

    @NSManaged var name: String
    @NSManaged var address: String

    func loadContent(json: NSDictionary) -> Self {
        self.name = json.objectForKey("name") as! String
        self.address = json.objectForKey("address") as! String
        return self
    }
    
    func JSON() -> NSDictionary {
        return NSDictionary()
    }
}
