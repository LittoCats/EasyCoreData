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
class Entity: NSManagedObject {

    @NSManaged var name: String
    @NSManaged var address: String

}
