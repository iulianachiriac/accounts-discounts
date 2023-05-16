@isTest
public class AccountTriggerTest {
  //more than 40,000 accounts have to be updated regularly
  private static final Integer NUM_OF_ACCOUNTS = 4;
  private static final Integer NUM_OF_CHILD_ACCOUNTS = 10;
  private static final Decimal DISCOUNT = 50;

  @TestSetup
  static void makeData() {
    List<Account> parentAccounts = new List<Account>();

    for (Integer i = 0; i < NUM_OF_ACCOUNTS; i++) {
      Account accParent = new Account(
        Name = 'Test Parent Account ' + i,
        Discount__c = 20
      );
      parentAccounts.add(accParent);
    }
    Test.startTest();
    insert parentAccounts;
    Test.stopTest();
  }

  @isTest
  private static void updateDiscountOnParent_unlockedDiscount() {
    List<Account> parents = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT :NUM_OF_ACCOUNTS
    ];

    List<Account> childAccounts = createChildAccounts(parents, false);

    for (Account parent : parents) {
      parent.Discount__c = DISCOUNT;
    }
    Test.startTest();
    update parents;
    Test.stopTest();

    childAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childAccounts
    ];

    for (Account c : childAccounts) {
      Assert.areEqual(
        DISCOUNT,
        c.Discount__c,
        'Failed to get expected discount on child Accounts'
      );
    }
  }

  @isTest
  private static void updateDiscountOnParent_lockedDiscount() {
    List<Account> parents = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT :NUM_OF_ACCOUNTS
    ];

    List<Account> childAccounts = createChildAccounts(parents, true);

    for (Account parent : parents) {
      parent.Discount__c = DISCOUNT;
    }
    Test.startTest();
    update parents;
    Test.stopTest();

    childAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childAccounts
    ];
    /*if HasLockedDiscount__c is true,
     *than the discount on child accounts
     *should be = 0 not null
     */
    for (Account c : childAccounts) {
      Assert.areEqual(
        0,
        c.Discount__c,
        'Failed to get expected discount on child Accounts'
      );
    }
  }

  @isTest
  private static void reparentingAccounts() {
    List<Account> firstAccount = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT 1
    ];
    Id firstAccId = firstAccount[0].Id;

    List<Account> childAccounts = createChildAccounts(firstAccount, false);
    Account secondAccount = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Name LIKE 'Test Parent Account%' AND Id != :firstAccId
      LIMIT 1
    ];
    Id secondAccId = secondAccount.Id;
    secondAccount.Discount__c = DISCOUNT;
    update secondAccount;

    childAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Account.ParentId = :firstAccount
    ];
    for (Account c : childAccounts) {
      c.ParentId = secondAccId;
    }

    Test.startTest();
    update childAccounts;
    Test.stopTest();
    //count of child accounts related to first account
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Account
        WHERE ParentId = :firstAccId AND Discount__c = 20
      ],
      'Failed to get expected amount of child accounts and discount on first account'
    );
    /*count of child accounts related to second account
     *(discount on current parent account
     *should be =:DISCOUNT after update)
     */
    Assert.areEqual(
      NUM_OF_ACCOUNTS,
      [
        SELECT COUNT()
        FROM Account
        WHERE ParentId = :secondAccId AND Discount__c = :DISCOUNT
      ],
      'Failed to get expected amount of child accounts and discount on current account'
    );
  }

  @isTest
  private static void deleteAndUndeleteAccounts() {
    List<Account> parents = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT :NUM_OF_ACCOUNTS
    ];

    List<Account> childAccounts = createChildAccounts(parents, false);
    Test.startTest();
    delete parents;

    childAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childAccounts
    ];
    /*When deleting a parent account,
     *child accounts' discount should be = 0
     *(if the discount field is unlocked)
     */
    for (Account c : childAccounts) {
      Assert.areEqual(
        0,
        c.Discount__c,
        'Failed to get expected discount on child Accounts after delete'
      );
    }

    undelete parents;
    Test.stopTest();

    childAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childAccounts
    ];
    /*When undeleting a parent account,
     *child accounts' discount should be = discount of the parent
     *(if the discount field is unlocked)
     */
    for (Account c : childAccounts) {
      Assert.areEqual(
        20,
        c.Discount__c,
        'Failed to get expected discount on child Accounts after undelete'
      );
    }
  }

  private static List<Account> createChildAccounts(
    List<Account> parents,
    Boolean hasLockedDiscount
  ) {
    List<Account> childAccounts = new List<Account>();
    for (Account parentAccount : parents) {
      // first loop
      for (Integer i = 0; i < NUM_OF_CHILD_ACCOUNTS; i++) {
        Account childAccount1 = new Account(
          Name = 'Test Child Account 1 ' + i,
          ParentId = parentAccount.id,
          HasLockedDiscount__c = hasLockedDiscount
        );
        childAccounts.add(childAccount1);
        //second loop
        for (Integer j = 0; j < NUM_OF_CHILD_ACCOUNTS; j++) {
          Account childAccount2 = new Account(
            Name = 'Test Child Account 2 ' + j,
            ParentId = childAccount1.Id,
            HasLockedDiscount__c = false
          );
          childAccounts.add(childAccount2);
          // Third loop
          for (Integer k = 0; k < NUM_OF_CHILD_ACCOUNTS; k++) {
            Account childAccount3 = new Account(
              Name = 'Test Child Account 3 ' + k,
              ParentId = childAccount2.Id,
              HasLockedDiscount__c = false
            );
            childAccounts.add(childAccount3);
            // Fourth loop
            for (Integer l = 0; l < NUM_OF_CHILD_ACCOUNTS; l++) {
              Account childAccount4 = new Account(
                Name = 'Test Child Account 4 ' + l,
                HasLockedDiscount__c = false,
                ParentId = childAccount3.Id
              );
              childAccounts.add(childAccount4);
            }
          }
        }
      }
    }

    insert childAccounts;
    return childAccounts;
  }
}
