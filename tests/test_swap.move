#[test_only]
module contract::test_swap {
    use sui::test_scenario::{Self as test, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use contract::FUN::{Self, TreasuryStore};
    use contract::swap;

    // Test constants
    const ADMIN: address = @0x1;
    const USER: address = @0x2;
    const EXCHANGE_RATE: u64 = 100;
    const BASIS_POINTS_DENOMINATOR: u64 = 10000;

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

    // Test successful SUI to FUN swap
    #[test]
    fun test_swap_sui_for_fun() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        let sui_amount = 10_000_000; // 10 SUI
        let sui_coins = create_sui_coins(sui_amount, scenario);

        test::next_tx(scenario, USER);
        {
            let ctx = test::ctx(scenario);
            let (fun_tokens, remaining_sui) = swap::swap_sui_for_fun(
                &mut treasury_store,
                sui_coins,
                ctx
            );

            // Verify FUN tokens received
            let fun_amount = coin::value(&fun_tokens);
            let expected_fun = (sui_amount * EXCHANGE_RATE) - 
                ((sui_amount * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR * EXCHANGE_RATE);
            assert!(fun_amount == expected_fun, 0);

            // Verify remaining SUI
            let remaining_amount = coin::value(&remaining_sui);
            assert!(remaining_amount == sui_amount - (sui_amount * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR, 1);

            // Transfer tokens to user
            transfer::public_transfer(fun_tokens, USER);
            transfer::public_transfer(remaining_sui, USER);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test successful FUN to SUI burn
    #[test]
    fun test_burn_fun_for_sui() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        
        // First add some SUI to the treasury
        let initial_sui = create_sui_coins(100_000_000, scenario); // 100 SUI
        test::next_tx(scenario, ADMIN);
        {
            let _ctx = test::ctx(scenario);
            FUN::add_sui_fees(&mut treasury_store, initial_sui);
        };
        
        // Now swap some SUI for FUN
        let sui_amount = 10_000_000; // 10 SUI
        let sui_coins = create_sui_coins(sui_amount, scenario);

        test::next_tx(scenario, USER);
        {
            let ctx = test::ctx(scenario);
            let (fun_tokens, remaining_sui) = swap::swap_sui_for_fun(
                &mut treasury_store,
                sui_coins,
                ctx
            );
            transfer::public_transfer(fun_tokens, USER);
            transfer::public_transfer(remaining_sui, USER);
        };

        // Now burn FUN for SUI
        test::next_tx(scenario, USER);
        {
            let fun_coins = test::take_from_address<Coin<FUN::FUN>>(scenario, USER);
            let ctx = test::ctx(scenario);
            let sui_returned = swap::burn_fun_for_sui(
                &mut treasury_store,
                fun_coins,
                ctx
            );

            // Verify returned SUI amount
            let returned_amount = coin::value(&sui_returned);
            let expected_sui = (sui_amount - (sui_amount * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR) - 
                ((sui_amount - (sui_amount * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR) * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR;
            assert!(returned_amount == expected_sui, 2);

            transfer::public_transfer(sui_returned, USER);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test swapping zero SUI (should fail)
    #[test]
    #[expected_failure(abort_code = contract::swap::EInvalidAmount)]
    fun test_swap_zero_sui() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        let sui_coins = create_sui_coins(0, scenario);

        test::next_tx(scenario, USER);
        {
            let ctx = test::ctx(scenario);
            let (fun_tokens, remaining_sui) = swap::swap_sui_for_fun(
                &mut treasury_store,
                sui_coins,
                ctx
            );
            transfer::public_transfer(fun_tokens, USER);
            transfer::public_transfer(remaining_sui, USER);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test burning insufficient FUN (should fail)
    #[test]
    #[expected_failure(abort_code = contract::swap::EInvalidAmount)]
    fun test_burn_insufficient_fun() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        
        // First add some SUI to the treasury
        let initial_sui = create_sui_coins(100_000_000, scenario); // 100 SUI
        test::next_tx(scenario, ADMIN);
        {
            let _ctx = test::ctx(scenario);
            FUN::add_sui_fees(&mut treasury_store, initial_sui);
        };
        
        // Create less than EXCHANGE_RATE FUN tokens
        test::next_tx(scenario, ADMIN);
        {
            let _ctx = test::ctx(scenario);
            let fun_tokens = FUN::mint(&mut treasury_store, EXCHANGE_RATE - 1, _ctx);
            transfer::public_transfer(fun_tokens, USER);
        };

        test::next_tx(scenario, USER);
        {
            let fun_coins = test::take_from_address<Coin<FUN::FUN>>(scenario, USER);
            let ctx = test::ctx(scenario);
            let sui_returned = swap::burn_fun_for_sui(
                &mut treasury_store,
                fun_coins,
                ctx
            );
            transfer::public_transfer(sui_returned, USER);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }

    // Test fee collection
    #[test]
    fun test_fee_collection() {
        let (mut scenario_val, mut treasury_store) = setup_test();
        let scenario = &mut scenario_val;
        
        // First add some SUI to the treasury
        let initial_sui = create_sui_coins(100_000_000, scenario); // 100 SUI
        test::next_tx(scenario, ADMIN);
        {
            let _ctx = test::ctx(scenario);
            FUN::add_sui_fees(&mut treasury_store, initial_sui);
        };
        
        let sui_amount = 10_000_000; // 10 SUI
        let sui_coins = create_sui_coins(sui_amount, scenario);

        // Record initial fee balance
        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let (initial_sui_fees, initial_fun_fees) = FUN::collect_fees(&mut treasury_store, ctx);
            transfer::public_transfer(initial_sui_fees, ADMIN);
            transfer::public_transfer(initial_fun_fees, ADMIN);
        };

        test::next_tx(scenario, USER);
        {
            let ctx = test::ctx(scenario);
            let (fun_tokens, remaining_sui) = swap::swap_sui_for_fun(
                &mut treasury_store,
                sui_coins,
                ctx
            );
            transfer::public_transfer(fun_tokens, USER);
            transfer::public_transfer(remaining_sui, USER);
        };

        // Verify SUI fees were collected
        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let (sui_fees, fun_fees) = FUN::collect_fees(&mut treasury_store, ctx);
            let sui_fee_amount = coin::value(&sui_fees);
            let expected_sui_fees = (sui_amount * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR;
            assert!(sui_fee_amount == expected_sui_fees, 3);
            transfer::public_transfer(sui_fees, ADMIN);
            transfer::public_transfer(fun_fees, ADMIN);
        };

        // Add more SUI to the treasury for burning FUN tokens
        let more_sui = create_sui_coins(100_000_000, scenario); // 100 SUI
        test::next_tx(scenario, ADMIN);
        {
            let _ctx = test::ctx(scenario);
            FUN::add_sui_fees(&mut treasury_store, more_sui);
        };

        // Now burn FUN for SUI
        test::next_tx(scenario, USER);
        {
            let fun_coins = test::take_from_address<Coin<FUN::FUN>>(scenario, USER);
            let ctx = test::ctx(scenario);
            let sui_returned = swap::burn_fun_for_sui(
                &mut treasury_store,
                fun_coins,
                ctx
            );
            transfer::public_transfer(sui_returned, USER);
        };

        // Verify FUN fees were collected
        test::next_tx(scenario, ADMIN);
        {
            let ctx = test::ctx(scenario);
            let (sui_fees, fun_fees) = FUN::collect_fees(&mut treasury_store, ctx);
            let fun_fee_amount = coin::value(&fun_fees);
            let expected_fun_fees = ((sui_amount - (sui_amount * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR) * EXCHANGE_RATE * FUN::get_fee_bps(&treasury_store)) / BASIS_POINTS_DENOMINATOR;
            assert!(fun_fee_amount == expected_fun_fees, 4);
            transfer::public_transfer(sui_fees, ADMIN);
            transfer::public_transfer(fun_fees, ADMIN);
        };

        test::return_shared(treasury_store);
        test::end(scenario_val);
    }
} 