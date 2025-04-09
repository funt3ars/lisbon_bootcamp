// # Challenge 2
// This module implements a custom cryptocurrency called FUN. It includes functionality to initialize the coin, 
// mint and burn FUN tokens, and manage fees for treasury operations.
module contract::FUN {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use std::ascii;

    /// Error codes
    const EInvalidFeePercentage: u64 = 0;

    /// Constants
    /// Denominator for basis points calculations (1 basis point = 0.01%)
    const BASIS_POINTS_DENOMINATOR: u64 = 10000;
    /// Default fee rate in basis points (0.3%)
    const DEFAULT_FEE_BPS: u64 = 30;

    /// The FUN coin type
    public struct FUN has drop {}

    /// Holds the treasury and fee collection capabilities
    /// - treasury_cap: Capability to mint and burn FUN tokens
    /// - sui_fees: Accumulated SUI fees from operations
    /// - fun_fees: Accumulated FUN fees from operations
    /// - fee_bps: Fee rate in basis points (1 basis point = 0.01%)
    public struct TreasuryStore has key {
        id: UID,
        treasury_cap: TreasuryCap<FUN>,
        sui_fees: Balance<SUI>,
        fun_fees: Balance<FUN>,
        fee_bps: u64
    }

    /// Initializes the FUN coin by creating its metadata and treasury capabilities.
    /// This function is called once when the module is published.
    /// 
    /// Decimals is set to 9 because:
    /// - Provides maximum precision for token operations
    /// - Allows for fine-grained control over token amounts
    /// - Common standard in many cryptocurrencies (e.g., Bitcoin)
    /// 
    /// The metadata is frozen because:
    /// - It ensures immutability of coin properties after creation
    /// - Builds trust with users as properties can't be changed
    /// - Follows best practices in cryptocurrency design
    /// - Prevents potential manipulation of coin characteristics
    fun init(witness: FUN, ctx: &mut TxContext) {
        let decimals: u8 = 9;
        let symbol: vector<u8> = b"FUN";
        let name: vector<u8> = b"FUN Token";
        let description: vector<u8> = b"A fun token for learning Sui Move";
        let icon_url = url::new_unsafe(ascii::string(b"https://raw.githubusercontent.com/sui-foundation/sui-move-intro-course/main/unit-three/example_projects/fun_token/fun_logo.png"));

        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            decimals,
            symbol,
            name,
            description,
            option::some(icon_url),
            ctx
        );

        // Create and share treasury store
        let treasury_store = TreasuryStore {
            id: object::new(ctx),
            treasury_cap,
            sui_fees: balance::zero(),
            fun_fees: balance::zero(),
            fee_bps: DEFAULT_FEE_BPS
        };
        
        transfer::share_object(treasury_store);
        transfer::public_freeze_object(metadata);
    }

    /// Mints new FUN coins
    /// @param store - The treasury store containing minting capability
    /// @param amount - The amount of FUN tokens to mint
    /// @param ctx - The transaction context
    /// @return A new coin containing the minted FUN tokens
    public fun mint(store: &mut TreasuryStore, amount: u64, ctx: &mut TxContext): Coin<FUN> {
        coin::mint(&mut store.treasury_cap, amount, ctx)
    }

    /// Burns FUN coins
    /// @param store - The treasury store containing burning capability
    /// @param coin - The FUN coins to burn
    public fun burn(store: &mut TreasuryStore, coin: Coin<FUN>) {
        coin::burn(&mut store.treasury_cap, coin);
    }

    /// Allows treasury owner to collect accumulated fees
    /// @param store - The treasury store containing the fees
    /// @param ctx - The transaction context
    /// @return A tuple containing the collected SUI and FUN fees as coins
    public fun collect_fees(
        store: &mut TreasuryStore, 
        ctx: &mut TxContext
    ): (Coin<SUI>, Coin<FUN>) {
        let sui_fees = coin::from_balance(balance::withdraw_all(&mut store.sui_fees), ctx);
        let fun_fees = coin::from_balance(balance::withdraw_all(&mut store.fun_fees), ctx);
        (sui_fees, fun_fees)
    }

    /// Updates the fee percentage (in basis points)
    /// @param store - The treasury store to update
    /// @param new_fee_bps - The new fee rate in basis points (1 basis point = 0.01%)
    public fun update_fee(store: &mut TreasuryStore, new_fee_bps: u64) {
        assert!(new_fee_bps <= BASIS_POINTS_DENOMINATOR, EInvalidFeePercentage);
        store.fee_bps = new_fee_bps;
    }

    /// Gets the current fee rate in basis points
    public fun get_fee_bps(store: &TreasuryStore): u64 {
        store.fee_bps
    }

    /// Adds SUI fees to the treasury
    public fun add_sui_fees(store: &mut TreasuryStore, fee: Coin<SUI>) {
        balance::join(&mut store.sui_fees, coin::into_balance(fee));
    }

    /// Adds FUN fees to the treasury
    public fun add_fun_fees(store: &mut TreasuryStore, fee: Coin<FUN>) {
        balance::join(&mut store.fun_fees, coin::into_balance(fee));
    }

    /// Withdraws SUI fees from the treasury
    public fun withdraw_sui_fees(store: &mut TreasuryStore, amount: u64): Balance<SUI> {
        balance::split(&mut store.sui_fees, amount)
    }

    #[test_only]
    /// Initialize the FUN coin for testing
    public fun init_for_testing(ctx: &mut TxContext) {
        init(FUN {}, ctx)
    }
}