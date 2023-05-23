@isTest
public class AccountTriggerTest {
  //more than 40,000 accounts have to be updated regularly
  private static final Integer NUM_OF_TOP_LEVEL_ACCOUNTS = 2;
  private static final Integer NUM_OF_CHILDREN_ACCOUNTS = 4;
  private static final Decimal PARENT_DISCOUNT = 50;

  @TestSetup
  static void makeData() {
    List<Account> topLevelAccounts = new List<Account>();

    for (Integer i = 0; i < NUM_OF_TOP_LEVEL_ACCOUNTS; i++) {
      Account topLevelAccount = new Account(
        Name = 'Test Top Level Account' + i,
        Discount__c = 20,
        HasLockedDiscount__c = false
      );
      topLevelAccounts.add(topLevelAccount);
    }
    Test.startTest();
    insert topLevelAccounts;
    Test.stopTest();
  }

  @isTest
  private static void itShouldUpdateDiscountOnUnlockedChildrenIfParentDiscountChanges() {
    List<Account> topLevelAccounts = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT :NUM_OF_TOP_LEVEL_ACCOUNTS
    ];

    List<Account> childrenAccounts = itShouldCreateChildrenAccounts(
      topLevelAccounts,
      false
    );

    for (Account topLevelAccount : topLevelAccounts) {
      topLevelAccount.Discount__c = PARENT_DISCOUNT;
    }
    Test.startTest();
    update topLevelAccounts;
    Test.stopTest();

    childrenAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childrenAccounts
    ];

    for (Account c : childrenAccounts) {
      Assert.areEqual(
        PARENT_DISCOUNT,
        c.Discount__c,
        'Failed to get expected discount on unlocked children accounts'
      );
    }
  }

  @isTest
  private static void itShouldUpdateDiscountOnLockedChildrenToZeroIfParentDiscountChanges() {
    List<Account> topLevelAccounts = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT :NUM_OF_TOP_LEVEL_ACCOUNTS
    ];

    List<Account> childrenAccounts = itShouldCreateChildrenAccounts(
      topLevelAccounts,
      true
    );

    for (Account topLevelAccount : topLevelAccounts) {
      topLevelAccount.Discount__c = PARENT_DISCOUNT;
    }
    Test.startTest();
    update topLevelAccounts;
    Test.stopTest();

    childrenAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childrenAccounts
    ];
    /**
     * if HasLockedDiscount__c is true,
     *then the discount on children accounts
     *should be = 0 not null
     */
    for (Account c : childrenAccounts) {
      Assert.areEqual(
        0,
        c.Discount__c,
        'Failed to get expected discount on locked children accounts'
      );
    }
  }

  @isTest
  private static void itShouldChangeCurrentParentOfAccounts() {
    List<Account> firstParent = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT 1
    ];
    Id firstParentId = firstParent[0].Id;

    List<Account> childrenAccounts = itShouldCreateChildrenAccounts(
      firstParent,
      false
    );
    Account secondParent = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Name LIKE 'Test Top Level Account%' AND Id != :firstParentId
      LIMIT 1
    ];
    Id secondParentId = secondParent.Id;
    secondParent.Discount__c = PARENT_DISCOUNT;
    update secondParent;

    childrenAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Account.ParentId = :firstParentId
    ];
    for (Account c : childrenAccounts) {
      c.ParentId = secondParentId;
    }

    Test.startTest();
    update childrenAccounts;
    Test.stopTest();
    // count of children accounts related to first parent
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Account
        WHERE ParentId = :firstParentId AND Discount__c = 20
      ],
      'Failed to get expected amount of children accounts and discount on first parent'
    );
    /**
     * count of children accounts related to second parent
     * (discount on current parent account
     * should be =:PARENT_DISCOUNT after update)
     */
    Assert.areEqual(
      NUM_OF_TOP_LEVEL_ACCOUNTS,
      [
        SELECT COUNT()
        FROM Account
        WHERE ParentId = :secondParentId AND Discount__c = :PARENT_DISCOUNT
      ],
      'Failed to get expected amount of children accounts and discount on current account'
    );
  }

  @isTest
  private static void itShouldUpdateDiscountOnChildrenWhenDeletingAndUndeletingParents() {
    List<Account> topLevelAccounts = [
      SELECT Id, Discount__c
      FROM Account
      LIMIT :NUM_OF_TOP_LEVEL_ACCOUNTS
    ];

    List<Account> childrenAccounts = itShouldCreateChildrenAccounts(
      topLevelAccounts,
      false
    );
    Test.startTest();
    delete topLevelAccounts;

    childrenAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childrenAccounts
    ];
    /**
     * When deleting a parent account,
     * children accounts' discount should be = 0
     * (if the discount field is unlocked)
     */
    for (Account c : childrenAccounts) {
      Assert.areEqual(
        0,
        c.Discount__c,
        'Failed to get expected discount on children accounts after delete'
      );
    }

    undelete topLevelAccounts;
    Test.stopTest();

    childrenAccounts = [
      SELECT Id, Discount__c
      FROM Account
      WHERE Id IN :childrenAccounts
    ];
    /**
     * When undeleting a parent account,
     * children accounts' discount should be = discount of the parent
     * (if the discount field is unlocked)
     */
    for (Account c : childrenAccounts) {
      Assert.areEqual(
        20,
        c.Discount__c,
        'Failed to get expected discount on children accounts after undelete'
      );
    }
  }

  /**
   * This method creates 4 levels of accounts
   * (each one with their children accounts, except the last one)
   * @param topLevelAccounts
   * @param hasLockedDiscount
   * @return  `List<Account>`
   */
  private static List<Account> itShouldCreateChildrenAccounts(
    List<Account> topLevelAccounts,
    Boolean hasLockedDiscount
  ) {
    List<Account> childrenAccounts = new List<Account>();
    List<Account> secondLevelAccounts = new List<Account>();

    // Create second-level accounts
    for (Account topLevelAccount : topLevelAccounts) {
      for (Integer i = 0; i < NUM_OF_CHILDREN_ACCOUNTS; i++) {
        Account secondLevelAccount = new Account(
          Name = 'Test Second Level Account ' + i,
          ParentId = topLevelAccount.Id,
          HasLockedDiscount__c = hasLockedDiscount
        );
        secondLevelAccounts.add(secondLevelAccount);
      }
    }

    insert secondLevelAccounts;
    childrenAccounts.addAll(secondLevelAccounts);
    Assert.areEqual(
      topLevelAccounts.size() * NUM_OF_CHILDREN_ACCOUNTS,
      secondLevelAccounts.size(),
      'Failed to get expected size of second level accounts list)'
    );

    List<Account> thirdLevelAccounts = new List<Account>();

    // Create third-level accounts
    for (Account secondLevelAccount : secondLevelAccounts) {
      for (Integer i = 0; i < NUM_OF_CHILDREN_ACCOUNTS; i++) {
        Account thirdLevelAccount = new Account(
          Name = 'Test Third Level Account ' + i,
          ParentId = secondLevelAccount.Id,
          HasLockedDiscount__c = false
        );
        thirdLevelAccounts.add(thirdLevelAccount);
      }
    }

    insert thirdLevelAccounts;
    childrenAccounts.addAll(thirdLevelAccounts);
    Assert.areEqual(
      secondLevelAccounts.size() * NUM_OF_CHILDREN_ACCOUNTS,
      thirdLevelAccounts.size(),
      'Failed to get expected size of third level accounts list)'
    );

    List<Account> fourthLevelAccounts = new List<Account>();

    // Create fourth-level accounts
    for (Account thirdLevelAccount : thirdLevelAccounts) {
      for (Integer i = 0; i < NUM_OF_CHILDREN_ACCOUNTS; i++) {
        Account fourthLevelAccount = new Account(
          Name = 'Test Fourth Level Account ' + i,
          ParentId = thirdLevelAccount.Id,
          HasLockedDiscount__c = false
        );
        fourthLevelAccounts.add(fourthLevelAccount);
      }
    }

    insert fourthLevelAccounts;
    childrenAccounts.addAll(fourthLevelAccounts);
    Assert.areEqual(
      thirdLevelAccounts.size() * NUM_OF_CHILDREN_ACCOUNTS,
      fourthLevelAccounts.size(),
      'Failed to get expected size of fourth level accounts list)'
    );

    Assert.areEqual(
      NUM_OF_CHILDREN_ACCOUNTS *
      (topLevelAccounts.size() +
      secondLevelAccounts.size() +
      thirdLevelAccounts.size()),
      childrenAccounts.size(),
      'Failed to get expected size of children accounts list'
    );

    return childrenAccounts;
  }
}
