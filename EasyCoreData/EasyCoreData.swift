//
//  EasyCoreData.swift
//  EasyCoreData
//
//  Created by 程巍巍 on 3/18/15.
//  Copyright (c) 2015 Littocats. All rights reserved.

//  同一个线中程，将返回同一个 context，了线程中的 context 数据在 save 时自动同步到主线程 context，
//  context 同步过程为异步执行，子线程中 save 完成，主线程中的数据同步可能有延迟，保存到文件可能进一步被延迟

/*

结构图

  ******************************         *****************     *************
  *      BackgroundContext     *    ->   *     Save      * ->  *    PSD    * -> file system
  ******************************         *****************     *************
                |
                ^
                |
                -----<---------------------------------------<---
                                                                ^
  ******************************         *****************      |
  *        MainContext         *    ->   *     Save      * 	-----
  ******************************         *****************
                |           |
                ^           |                       ******************************    ***********************
                |           ---------->-------->----*     Object did changed     * -> *     Update UIView   *  -> other task with UI
                |                                   ******************************    ***********************
                ^
                |
                ----------------------<-----------------------<-----<----------
                                                                ^             ^
   ***************************         *****************        |             |
   *       CustomContext     *  --->   *     Save      * ----->--     ******************
   ***************************         *****************        |     *      Save      * <- AnyContext out of mainThread
                                                                |     ******************
                                                                ^
                                                                |
  ****************************         *****************        |
  *        CustomContext     *  ---->   *     Save      * --->---
  ****************************         *****************

*/

import CoreData

func EMOC(momd: String) -> NSManagedObjectContext{
    return EasyCoreData.context(momd: momd)
}

struct EasyCoreData {
    private static var ContextTable = NSMapTable.weakToStrongObjectsMapTable()
    /**
    *  获取当前线程中的 context
    *  momd 为所要管理的 model
    *  不要在不同的线程中传递 NSManagedObjectContext / NSManagedObejct.
    *  需的context 的时候，一般情况下，应使用此方法获取，NSManagedObject 应由 [NSManagedObjectContext objectWithID:NSManagedObjectID] 获得
    *  Notice : 不允许重新设置 parentContext 及 persistentStoreCoordinator ,否则出错
    */
    static func context(#momd: String) ->NSManagedObjectContext{
        if NSThread.currentThread().isMainThread {
            return MainContext.context(mom: momd)
        }else{
            return CustomContext.context(mom: momd)
        }
    }
}

extension EasyCoreData {
    class BaseContext: NSManagedObjectContext {
        private var mom: String = ""
        
        private class func context(#mom: String) -> NSManagedObjectContext{
            var table: NSMapTable?
            table = EasyCoreData.ContextTable.objectForKey(NSThread.currentThread()) as? NSMapTable
            if table == nil {
                table = NSMapTable.strongToWeakObjectsMapTable()
                EasyCoreData.ContextTable.setObject(table!, forKey: NSThread.currentThread())
            }
            var context = table?.objectForKey(mom) as? BaseContext
            if context == nil {
                context = self()
                context?.mom = mom
                table?.setObject(context!, forKey: mom)
            }
            return context!
        }
        
        override func save(error: NSErrorPointer) -> Bool {
            var ret = super.save(error)
            var parentContext = self.parentContext
            parentContext?.performBlock({ () -> Void in
                var e = error
                parentContext?.save(error)
            })
            return ret
        }
    }
    
    private final class BackgroundContext: BaseContext {
        
        convenience init(){
            self.init(concurrencyType: .PrivateQueueConcurrencyType)
        }
        
        private override class func context(#mom: String) -> NSManagedObjectContext{
            var context = EasyCoreData.ContextTable.objectForKey("BGMOC_\(mom)") as? BackgroundContext
            if context == nil{
                context = BackgroundContext()
                context?.mom = mom
                EasyCoreData.ContextTable.setObject(context!, forKey: "BGMOC_\(mom)")
            }
            return context!
        }
        
        /**
        *
        */
        override var mom: String{
            didSet{
                self.persistentStoreCoordinator = syncPersistentStoreCoordinator()
            }
        }
        //程序运行过程中，一个model对应的 NSPersistentStoreCoordinator 有且仅有一个
        //因为背景 context 是其它 context 的父 context 或祖先 context ,所以该方法只会被调用一次（同一个 momd）
        private func syncPersistentStoreCoordinator() ->NSPersistentStoreCoordinator{
            
            // 获取 Model 及 PersistentStoreCoordinator
            var momdURL = NSBundle.mainBundle().URLForResource(self.mom, withExtension: "momd")
            assert(momdURL != nil, "CoreData model \"\(mom)\" not exist .\n")
            var model = NSManagedObjectModel(contentsOfURL: momdURL!)
            assert(model != nil, "CoreData model \"\(mom)\" load error.\n")
            var psc = NSPersistentStoreCoordinator(managedObjectModel: model!)
            
            // 获取数据库存储路径
            var error: NSError?
            var storeURL: NSURL? = NSFileManager.defaultManager().URLForDirectory(.LibraryDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true, error: &error)
            assert(error == nil && storeURL != nil, "CoreData PersistentStore error for model \"\(mom)\"")
            storeURL = storeURL?.URLByAppendingPathComponent("db")
            if !NSFileManager.defaultManager().fileExistsAtPath(storeURL!.path!){
                NSFileManager.defaultManager().createDirectoryAtURL(storeURL!, withIntermediateDirectories: true, attributes: nil, error: &error)
                assert(error == nil, "CoreData PersistentStore error for model \"\(mom)\"")
            }
            
            // 设置 数据库轻量级迁移设置
            var options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
            if (psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL!.URLByAppendingPathComponent("\(mom).\(NSSQLiteStoreType)"), options: options, error: &error) == nil){
                NSLog("failed to add persistent store with type to persistent store coordinator < \(mom) >")
                abort()
            }
            return psc
        }
    }
    
    private final class MainContext: BaseContext {
        
        convenience init(){
            self.init(concurrencyType: .MainQueueConcurrencyType)
        }
        override var mom: String{
            didSet{
                self.parentContext = BackgroundContext.context(mom: self.mom)
            }
        }
        override func performBlockAndWait(block: () -> Void) {
            block()
        }
    }
    
    private final class CustomContext: BaseContext{
        
        convenience init(){
            self.init(concurrencyType: .PrivateQueueConcurrencyType)
        }
        
        override var mom: String{
            didSet{
                dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                    self.parentContext = EasyCoreData.context(momd: self.mom)
                })
            }
        }
    }
}

protocol NSManagedObjectJSONProtocol {
    func loadContent(json: NSDictionary) ->Self
    func JSON()->NSDictionary
}

extension NSManagedObjectContext {
    /**
    *  insert
    */
    final func insert<T: NSManagedObject>(#entity: T.Type) ->T{
        var entityName: String = NSString(UTF8String: class_getName(entity))! as String
        var entityDescription = (self.persistentStoreCoordinator?.managedObjectModel.entitiesByName as? [String: NSEntityDescription])?[entityName]
        var ret: T = entity(entity: entityDescription!, insertIntoManagedObjectContext: self)
        
        return ret
    }
    
    final func insert<T where T: NSManagedObject, T: NSManagedObjectJSONProtocol>(#entity: T.Type, content json: NSDictionary) ->T{
        var ret: T = self.insert(entity: entity)
        ret.loadContent(json)
        return ret
    }
    
    /**
    *  查询数据
    *  @entityName
    *  @limit
    *  @offset
    *  @sort NSSortDescriptor The sort descriptors specify how the objects returned when the fetch request is issued should be ordered—for example by last name then by first name. The sort descriptors are applied in the order in which they appear in the sortDescriptors array (serially in lowest-array-index-first order).A value of nil is treated as no sort descriptors.
    *  @predicate  The predicate is used to constrain the selection of objects the receiver is to fetch.
    */
    final func objects<T: NSManagedObject>(#entity: T.Type, predicate: NSPredicate? = nil, sortors: [NSSortDescriptor]? = nil, limit: Int? = nil, offset: Int? = nil) ->[T]{
        var entityName = NSString(UTF8String: class_getName(entity))!
        var request: NSFetchRequest = NSFetchRequest(entityName: entityName as String)
        request.predicate = predicate
        request.sortDescriptors = sortors
        if limit != nil {request.fetchLimit = limit!}
        if offset != nil {request.fetchOffset = offset!}
        
        request.shouldRefreshRefetchedObjects = false
        
        var ret: [T] = [T]()
        var error: NSError?
        self.performBlockAndWait { () -> Void in
            var pRet = self.executeFetchRequest(request, error: &error) as? [T]
            if pRet != nil {ret = pRet!}
        }
        return ret
    }
    
    /**
    *   根据实体类型，删除记录
    */
    final func delete<T: NSManagedObject>(#entity: T.Type, predicate: NSPredicate? = nil) ->Void{
        self.objects(entity: entity, predicate: predicate).map {(transform: T) -> Void in
            self.deleteObject(transform)
        }
    }
    
    /**
    *   因为 ContextTable  没有对 moc (self) 强引用，在超出 moc 所在的语法范围后，moc 将会释放，如果在同一线程中多个语法范围内获取 moc ，将会出现频繁生成 moc 实例的情况
    *   调用 cache() 方法，将 moc 与所在线程关联，即使超出语法范围，在线程（NSThread 实例) 关闭（释放）前，moc 不会被释放
    */
    final func cache() ->Self{
        var cache = EasyCoreData.ContextTable.objectForKey(NSThread.currentThread()) as? NSMapTable
        cache?.setObject(self as NSManagedObjectContext, forKey: cache!)
        return self
    }
    
    /**
    *   解除 moc 与所在线程的关联
    */
    final func deCache() ->Self{
        var cache = EasyCoreData.ContextTable.objectForKey(NSThread.currentThread()) as? NSMapTable
        cache?.removeObjectForKey(self as NSManagedObjectContext)
        return self
    }
}

