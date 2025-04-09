#[test_only]
module contract::test_fun {
    use sui::test_scenario::{Self as test, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use contract::FUN::{Self, TreasuryStore};

    // Test constants
    const ADMIN: address = @0x1;
    const BASIS_POINTS_DENOMINATOR: u64 = 10000;
    const DEFAULT_FEE_BPS: u64 = 30;

    // Helper function to initialize the treasury store
    fun setup_test(): (Scenario, TreasuryStore) {
        let mut scenario_val = test::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        // Initialize FUN token and treasury store
        {
            let _ctx = test::ctx(scenario);
            FUN::init_for_testing(_ctx);
            test::next_tx(scenario, ADMIN);
        };
        
        {
            let treasury_store = test::take_shared<TreasuryStore>(scenario);
            (scenario_val, treasury_store)
        }
    }

    // Helper function to create SUI coins
    fun create_sui_coins(amount: u64, scenario: &mut Scenario): Coin<SUI> {
        let ctx = test::ctx(scenario);
        coin::mint_for_testing(amount, ctx)
    }

    // Test successful minting of FUN tokens
    #[test]
    fun test_mint_fun() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        let amount = 1000;

        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let fun_tokens = FUN::mint(&mut treasury_store, amount, ctx);
            
            // Verify minted amount
            let minted_amount = coin::value(&fun_tokens);
            assert!(minted_amount == amount, 0);
            
            transfer::public_transfer(fun_tokens, ADMIN);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test successful burning of FUN tokens
    #[test]
    fun test_burn_fun() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        let amount = 1000;

        // First mint some FUN tokens
        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let fun_tokens = FUN::mint(&mut treasury_store, amount, ctx);
            transfer::public_transfer(fun_tokens, ADMIN);
        };

        // Now burn the FUN tokens
        test::next_tx(scenario, ADMIN);
        {
            let fun_tokens = test::take_from_address<Coin<FUN::FUN>>(scenario, ADMIN);
            FUN::burn(&mut treasury_store, fun_tokens);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test fee collection
    #[test]
    fun test_fee_collection() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        
        // Add some SUI fees
        let sui_amount = 100_000_000; // 100 SUI
        let sui_coins = create_sui_coins(sui_amount, scenario);
        test::next_tx(scenario, ADMIN);
        {
            FUN::add_sui_fees(&mut treasury_store, sui_coins);
        };

        // Add some FUN fees
        let fun_amount = 1000;
        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let fun_tokens = FUN::mint(&mut treasury_store, fun_amount, ctx);
            FUN::add_fun_fees(&mut treasury_store, fun_tokens);
        };

        // Collect fees
        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let (sui_fees, fun_fees) = FUN::collect_fees(&mut treasury_store, ctx);
            
            // Verify collected amounts
            let collected_sui = coin::value(&sui_fees);
            let collected_fun = coin::value(&fun_fees);
            assert!(collected_sui == sui_amount, 1);
            assert!(collected_fun == fun_amount, 2);
            
            transfer::public_transfer(sui_fees, ADMIN);
            transfer::public_transfer(fun_fees, ADMIN);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test fee update
    #[test]
    fun test_update_fee() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        
        // Verify default fee
        let initial_fee = FUN::get_fee_bps(&treasury_store);
        assert!(initial_fee == DEFAULT_FEE_BPS, 3);

        // Update fee
        let new_fee = 50; // 0.5%
        test::next_tx(scenario, ADMIN);
        {
            FUN::update_fee(&mut treasury_store, new_fee);
        };

        // Verify new fee
        let updated_fee = FUN::get_fee_bps(&treasury_store);
        assert!(updated_fee == new_fee, 4);

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test invalid fee update (should fail)
    #[test]
    #[expected_failure(abort_code = contract::FUN::EInvalidFeePercentage)]
    fun test_invalid_fee_update() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        
        // Try to update fee to an invalid value
        test::next_tx(scenario, ADMIN);
        {
            FUN::update_fee(&mut treasury_store, BASIS_POINTS_DENOMINATOR + 1);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test SUI fee withdrawal
    #[test]
    fun test_withdraw_sui_fees() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        
        // Add some SUI fees
        let sui_amount = 100_000_000; // 100 SUI
        let sui_coins = create_sui_coins(sui_amount, scenario);
        test::next_tx(scenario, ADMIN);
        {
            FUN::add_sui_fees(&mut treasury_store, sui_coins);
        };

        // Withdraw a portion of the fees
        let withdraw_amount = 50_000_000; // 50 SUI
        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let sui_balance = FUN::withdraw_sui_fees(&mut treasury_store, withdraw_amount);
            let sui_coin = coin::from_balance(sui_balance, ctx);
            
            // Verify withdrawn amount
            let withdrawn_amount = coin::value(&sui_coin);
            assert!(withdrawn_amount == withdraw_amount, 5);
            
            transfer::public_transfer(sui_coin, ADMIN);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }
} 