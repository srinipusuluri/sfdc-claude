/**
 * AccountService_Test
 *
 * Unit tests for AccountService.  Targets >= 90 % coverage of that class.
 * Uses @TestSetup for shared data; no seeAllData = true.
 */
@IsTest
public with sharing class AccountService_Test {

    // ───────────────────────────────────────────────────────────
    // Shared test data
    // ───────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = '  Acme Corp  '),
            new Account(Name = 'Global Industries'),
            new Account(Name = '   Padded Name   ')
        };
        insert accounts;
    }

    // ───────────────────────────────────────────────────────────
    // Positive tests
    // ───────────────────────────────────────────────────────────

    @IsTest
    static void normalizeNames_trimsPadding() {
        // Build in-memory list; no DML needed to test the pure logic
        List<Account> testAccounts = new List<Account>{
            new Account(Name = '  Acme Corp  '),
            new Account(Name = '   Leading space'),
            new Account(Name = 'Trailing space   ')
        };

        Test.startTest();
        AccountService.normalizeNames(testAccounts);
        Test.stopTest();

        System.assertEquals('Acme Corp',      testAccounts[0].Name, 'Leading and trailing spaces should be removed');
        System.assertEquals('Leading space',  testAccounts[1].Name, 'Leading spaces should be removed');
        System.assertEquals('Trailing space', testAccounts[2].Name, 'Trailing spaces should be removed');
    }

    @IsTest
    static void normalizeNames_noOpWhenAlreadyTrimmed() {
        List<Account> testAccounts = new List<Account>{
            new Account(Name = 'Clean Name'),
            new Account(Name = 'Another Clean')
        };

        Test.startTest();
        AccountService.normalizeNames(testAccounts);
        Test.stopTest();

        System.assertEquals('Clean Name',    testAccounts[0].Name, 'Already-trimmed name should be unchanged');
        System.assertEquals('Another Clean', testAccounts[1].Name, 'Already-trimmed name should be unchanged');
    }

    @IsTest
    static void normalizeNames_handlesNullName() {
        List<Account> testAccounts = new List<Account>{
            new Account(Name = null)
        };

        Test.startTest();
        AccountService.normalizeNames(testAccounts);
        Test.stopTest();

        System.assertNotEquals('threw exception', 'threw exception', 'Null Name should not throw an exception');
        System.assertEquals(null, testAccounts[0].Name, 'Null Name should remain null');
    }

    // ───────────────────────────────────────────────────────────
    // Negative / edge-case tests
    // ───────────────────────────────────────────────────────────

    @IsTest
    static void normalizeNames_emptyListDoesNotThrow() {
        List<Account> emptyList = new List<Account>();

        Test.startTest();
        try {
            AccountService.normalizeNames(emptyList);
        } catch (Exception ex) {
            System.assert(false, 'Empty list should not throw: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assertEquals(0, emptyList.size(), 'List should still be empty');
    }

    @IsTest
    static void normalizeNames_nullListDoesNotThrow() {
        Test.startTest();
        try {
            AccountService.normalizeNames(null);
        } catch (Exception ex) {
            System.assert(false, 'Null list should not throw: ' + ex.getMessage());
        }
        Test.stopTest();

        // If we reach here, the null guard worked correctly
        System.assert(true, 'Null list handled gracefully');
    }

    @IsTest
    static void normalizeNames_bulkHandlesLargeList() {
        // Verify the method is bulk-safe with 200 records (one trigger batch)
        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            bulkAccounts.add(new Account(Name = '  Account ' + i + '  '));
        }

        Test.startTest();
        AccountService.normalizeNames(bulkAccounts);
        Test.stopTest();

        for (Integer i = 0; i < 200; i++) {
            System.assertEquals(
                'Account ' + i,
                bulkAccounts[i].Name,
                'Bulk record ' + i + ' should have trimmed name'
            );
        }
    }
}
