// This module implements swap functionality for the FUN token, allowing users to:
// 1. Swap SUI for FUN tokens at a fixed exchange rate
// 2. Burn FUN tokens to receive back SUI at the same rate
// Both operations include a fee that is collected in the treasury
module contract::swap {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use contract::FUN::{TreasuryStore};
    use contract::FUN;

    /// Error codes
    /// Amount is zero or less than the minimum required amount
    const EInvalidAmount: u64 = 0;

    /// Constants
    /// The exchange rate between SUI and FUN tokens
    /// 1 SUI = 100 FUN tokens
    const EXCHANGE_RATE: u64 = 100;
    const BASIS_POINTS_DENOMINATOR: u64 = 10000;

    /// Swaps SUI for FUN tokens at a constant rate with fee
    /// Rate: 1 SUI = 100 FUN tokens
    /// The fee is calculated based on the treasury store's fee_bps setting
    /// 
    /// @param store - The treasury store to mint FUN tokens and collect fees
    /// @param sui_payment - The SUI coins to swap
    /// @param ctx - The transaction context
    /// @return A new coin containing the minted FUN tokens and the remaining SUI
    public fun swap_sui_for_fun(
        store: &mut TreasuryStore,
        mut sui_payment: Coin<SUI>,
        ctx: &mut tx_context::TxContext
    ): (Coin<FUN::FUN>, Coin<SUI>) {
        let sui_amount = coin::value(&sui_payment);
        assert!(sui_amount > 0, EInvalidAmount);

        // Calculate fee
        let fee_amount = (sui_amount * FUN::get_fee_bps(store)) / BASIS_POINTS_DENOMINATOR;
        let swap_amount = sui_amount - fee_amount;

        // Split fee and add to fee balance
        let fee_coin = coin::split(&mut sui_payment, fee_amount, ctx);
        FUN::add_sui_fees(store, fee_coin);

        // Calculate FUN tokens to mint
        let fun_amount = swap_amount * EXCHANGE_RATE;
        
        // Mint FUN tokens
        let fun_tokens = FUN::mint(store, fun_amount, ctx);
        
        (fun_tokens, sui_payment)
    }

    /// Burns FUN tokens and returns SUI at the same rate with fee
    /// Rate: 100 FUN = 1 SUI
    /// The fee is calculated based on the treasury store's fee_bps setting
    /// 
    /// @param store - The treasury store to burn FUN tokens and collect fees
    /// @param fun_tokens - The FUN tokens to burn
    /// @param ctx - The transaction context
    /// @return A new coin containing the returned SUI tokens
    public fun burn_fun_for_sui(
        store: &mut TreasuryStore,
        mut fun_tokens: Coin<FUN::FUN>,
        ctx: &mut tx_context::TxContext
    ): Coin<SUI> {
        let fun_amount = coin::value(&fun_tokens);
        assert!(fun_amount >= EXCHANGE_RATE, EInvalidAmount);
    
        // Calculate fee
        let fee_amount = (fun_amount * FUN::get_fee_bps(store)) / BASIS_POINTS_DENOMINATOR;
        let swap_amount = fun_amount - fee_amount;

        // Split fee and add to fee balance
        let fee_coin = coin::split(&mut fun_tokens, fee_amount, ctx);
        FUN::add_fun_fees(store, fee_coin);

        // Calculate SUI to return
        let sui_amount = swap_amount / EXCHANGE_RATE;
        
        // Burn remaining FUN tokens
        FUN::burn(store, fun_tokens);
        
        // Return equivalent SUI from treasury
        coin::from_balance(FUN::withdraw_sui_fees(store, sui_amount), ctx)
    }
}
