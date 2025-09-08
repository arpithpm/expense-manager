import Foundation
import CoreData

@objc(ExpenseEntity)
public class ExpenseEntity: NSManagedObject {
    
}

extension ExpenseEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExpenseEntity> {
        return NSFetchRequest<ExpenseEntity>(entityName: "ExpenseEntity")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var merchant: String
    @NSManaged public var amount: Double
    @NSManaged public var currency: String
    @NSManaged public var category: String
    @NSManaged public var expenseDescription: String?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var taxAmount: Double
    @NSManaged public var receiptImageUrl: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var subtotal: Double
    @NSManaged public var discounts: Double
    @NSManaged public var fees: Double
    @NSManaged public var tip: Double
    @NSManaged public var itemsTotal: Double
    @NSManaged public var items: NSSet?
}

extension ExpenseEntity {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ExpenseItemEntity)
    
    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ExpenseItemEntity)
    
    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)
    
    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

@objc(ExpenseItemEntity)
public class ExpenseItemEntity: NSManagedObject {
    
}

extension ExpenseItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExpenseItemEntity> {
        return NSFetchRequest<ExpenseItemEntity>(entityName: "ExpenseItemEntity")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var quantity: Double
    @NSManaged public var unitPrice: Double
    @NSManaged public var totalPrice: Double
    @NSManaged public var category: String?
    @NSManaged public var itemDescription: String?
    @NSManaged public var expense: ExpenseEntity?
}

// MARK: - Conversion Extensions

extension ExpenseEntity {
    func toExpense() -> Expense {
        let expenseItems = (items?.allObjects as? [ExpenseItemEntity])?.map { $0.toExpenseItem() }
        
        return Expense(
            id: id,
            date: date,
            merchant: merchant,
            amount: amount,
            currency: currency,
            category: category,
            description: expenseDescription,
            paymentMethod: paymentMethod,
            taxAmount: taxAmount == 0 ? nil : taxAmount,
            receiptImageUrl: receiptImageUrl,
            createdAt: createdAt,
            updatedAt: updatedAt,
            items: expenseItems,
            subtotal: subtotal == 0 ? nil : subtotal,
            discounts: discounts == 0 ? nil : discounts,
            fees: fees == 0 ? nil : fees,
            tip: tip == 0 ? nil : tip,
            itemsTotal: itemsTotal == 0 ? nil : itemsTotal
        )
    }
    
    func updateFromExpense(_ expense: Expense, context: NSManagedObjectContext) {
        id = expense.id
        date = expense.date
        merchant = expense.merchant
        amount = expense.amount
        currency = expense.currency
        category = expense.category
        expenseDescription = expense.description
        paymentMethod = expense.paymentMethod
        taxAmount = expense.taxAmount ?? 0
        receiptImageUrl = expense.receiptImageUrl
        createdAt = expense.createdAt
        updatedAt = expense.updatedAt
        subtotal = expense.subtotal ?? 0
        discounts = expense.discounts ?? 0
        fees = expense.fees ?? 0
        tip = expense.tip ?? 0
        itemsTotal = expense.itemsTotal ?? 0
        
        // Clear existing items
        if let existingItems = items {
            removeFromItems(existingItems)
        }
        
        // Add new items
        if let expenseItems = expense.items {
            for item in expenseItems {
                let itemEntity = ExpenseItemEntity(context: context)
                itemEntity.updateFromExpenseItem(item)
                addToItems(itemEntity)
            }
        }
    }
}

extension ExpenseItemEntity {
    func toExpenseItem() -> ExpenseItem {
        return ExpenseItem(
            id: id,
            name: name,
            quantity: quantity == 0 ? nil : quantity,
            unitPrice: unitPrice == 0 ? nil : unitPrice,
            totalPrice: totalPrice,
            category: category,
            description: itemDescription
        )
    }
    
    func updateFromExpenseItem(_ item: ExpenseItem) {
        id = item.id
        name = item.name
        quantity = item.quantity ?? 0
        unitPrice = item.unitPrice ?? 0
        totalPrice = item.totalPrice
        category = item.category
        itemDescription = item.description
    }
}