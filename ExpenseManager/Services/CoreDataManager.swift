import Foundation
import CoreData

public class CoreDataManager: ObservableObject {
    public static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let model = createManagedObjectModel()
        let container = NSPersistentContainer(name: "ExpenseManager", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private init() {}
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data context: \(error)")
            }
        }
    }
    
    private func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create ExpenseEntity
        let expenseEntity = NSEntityDescription()
        expenseEntity.name = "ExpenseEntity"
        expenseEntity.managedObjectClassName = "ExpenseEntity"
        
        // ExpenseEntity attributes
        let expenseAttributes = [
            ("id", NSAttributeType.UUIDAttributeType, false),
            ("date", NSAttributeType.dateAttributeType, false),
            ("merchant", NSAttributeType.stringAttributeType, false),
            ("amount", NSAttributeType.doubleAttributeType, false),
            ("currency", NSAttributeType.stringAttributeType, false),
            ("category", NSAttributeType.stringAttributeType, false),
            ("expenseDescription", NSAttributeType.stringAttributeType, true),
            ("paymentMethod", NSAttributeType.stringAttributeType, true),
            ("taxAmount", NSAttributeType.doubleAttributeType, false),
            ("receiptImageUrl", NSAttributeType.stringAttributeType, true),
            ("createdAt", NSAttributeType.dateAttributeType, false),
            ("updatedAt", NSAttributeType.dateAttributeType, false),
            ("subtotal", NSAttributeType.doubleAttributeType, false),
            ("discounts", NSAttributeType.doubleAttributeType, false),
            ("fees", NSAttributeType.doubleAttributeType, false),
            ("tip", NSAttributeType.doubleAttributeType, false),
            ("itemsTotal", NSAttributeType.doubleAttributeType, false)
        ]
        
        for (name, type, isOptional) in expenseAttributes {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = isOptional
            expenseEntity.properties.append(attribute)
        }
        
        // Create ExpenseItemEntity
        let itemEntity = NSEntityDescription()
        itemEntity.name = "ExpenseItemEntity"
        itemEntity.managedObjectClassName = "ExpenseItemEntity"
        
        // ExpenseItemEntity attributes
        let itemAttributes = [
            ("id", NSAttributeType.UUIDAttributeType, false),
            ("name", NSAttributeType.stringAttributeType, false),
            ("quantity", NSAttributeType.doubleAttributeType, false),
            ("unitPrice", NSAttributeType.doubleAttributeType, false),
            ("totalPrice", NSAttributeType.doubleAttributeType, false),
            ("category", NSAttributeType.stringAttributeType, true),
            ("itemDescription", NSAttributeType.stringAttributeType, true)
        ]
        
        for (name, type, isOptional) in itemAttributes {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = isOptional
            itemEntity.properties.append(attribute)
        }
        
        // Create relationships
        let expenseToItemsRelationship = NSRelationshipDescription()
        expenseToItemsRelationship.name = "items"
        expenseToItemsRelationship.destinationEntity = itemEntity
        expenseToItemsRelationship.minCount = 0
        expenseToItemsRelationship.maxCount = 0 // 0 means unlimited
        expenseToItemsRelationship.deleteRule = .cascadeDeleteRule
        
        let itemToExpenseRelationship = NSRelationshipDescription()
        itemToExpenseRelationship.name = "expense"
        itemToExpenseRelationship.destinationEntity = expenseEntity
        itemToExpenseRelationship.minCount = 0
        itemToExpenseRelationship.maxCount = 1
        itemToExpenseRelationship.deleteRule = .nullifyDeleteRule
        
        // Set inverse relationships
        expenseToItemsRelationship.inverseRelationship = itemToExpenseRelationship
        itemToExpenseRelationship.inverseRelationship = expenseToItemsRelationship
        
        // Add relationships to entities
        expenseEntity.properties.append(expenseToItemsRelationship)
        itemEntity.properties.append(itemToExpenseRelationship)
        
        // Add entities to model
        model.entities = [expenseEntity, itemEntity]
        
        return model
    }
}