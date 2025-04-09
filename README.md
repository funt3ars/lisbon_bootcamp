# Challenge 2
In this challenge you are required to start a new smart contract. The end smart contract should include all the required functions as detailed below,
ideally it should also include tests.


1. Create a new coin
- pick a name
- pick decimals and be ready to explain why
- Freeze the CoinMetada object and be ready to explain the tradeoffs

2. Write a swap function that allows a user to get your Coin in exchange for SUI at a constant rate

3. Write a burn function that gives SUI in exchange for your Coin at the same rate and then it burns the Coin.

4. Bonus: Add a fee on the swap and burn that will go to you as the coin creator
5. Bonus II: Write tests

# Challenge 2 Implementation Documentation

# FUN Token and Swap Contract

This project implements a custom cryptocurrency called FUN and a swap mechanism to exchange between FUN and SUI tokens. The implementation consists of two main modules: `FUN` and `swap`.

## Table of Contents
1. [FUN Token Contract](#fun-token-contract)
   - [Overview](#overview)
   - [Key Features](#key-features)
   - [Implementation Details](#implementation-details)
   - [Test Suite](#test-suite)
2. [Swap Contract](#swap-contract)
   - [Overview](#overview-1)
   - [Key Features](#key-features-1)
   - [Implementation Details](#implementation-details-1)
   - [Test Suite](#test-suite-1)

## FUN Token Contract

### Overview
The FUN token is a custom cryptocurrency implemented on the Sui blockchain. It provides basic token functionality (minting and burning) along with a fee collection system.

### Key Features
- Token minting and burning
- Fee collection in both SUI and FUN tokens
- Configurable fee rate (in basis points)
- Treasury management
- Secure initialization with frozen metadata

### Implementation Details

#### Constants
- `BASIS_POINTS_DENOMINATOR`: 10000 (1 basis point = 0.01%)
- `DEFAULT_FEE_BPS`: 30 (0.3% default fee rate)

#### Error Codes
- `EInvalidFeePercentage`: Invalid fee percentage provided

#### Key Functions
1. `init(witness: FUN, ctx: &mut TxContext)`
   - Initializes the FUN token with metadata
   - Creates treasury capabilities
   - Sets up the treasury store

2. `mint(store: &mut TreasuryStore, amount: u64, ctx: &mut TxContext): Coin<FUN>`
   - Mints new FUN tokens
   - Returns the minted tokens as a coin

3. `burn(store: &mut TreasuryStore, coin: Coin<FUN>)`
   - Burns existing FUN tokens
   - Removes tokens from circulation

4. `collect_fees(store: &mut TreasuryStore, ctx: &mut TxContext): (Coin<SUI>, Coin<FUN>)`
   - Collects accumulated fees
   - Returns both SUI and FUN fees as coins

5. `update_fee(store: &mut TreasuryStore, new_fee_bps: u64)`
   - Updates the fee rate
   - Validates the new fee rate

6. `get_fee_bps(store: &TreasuryStore): u64`
   - Returns the current fee rate

### Test Suite

The FUN contract test suite (`test_fun.move`) includes the following tests:

1. `test_mint_fun()`
   - Tests successful minting of FUN tokens
   - Verifies correct amount is minted
   - Checks token transfer

2. `test_burn_fun()`
   - Tests successful burning of FUN tokens
   - Verifies tokens are properly burned
   - Includes minting step for test setup

3. `test_fee_collection()`
   - Tests fee collection functionality
   - Verifies both SUI and FUN fee collection
   - Checks correct amounts are collected

4. `test_update_fee()`
   - Tests fee rate updates
   - Verifies default fee rate
   - Confirms successful fee updates

5. `test_invalid_fee_update()`
   - Tests error handling for invalid fee rates
   - Verifies proper error code is raised
   - Ensures invalid updates are rejected

6. `test_withdraw_sui_fees()`
   - Tests partial SUI fee withdrawal
   - Verifies correct withdrawal amounts
   - Checks balance updates

## Swap Contract

### Overview
The swap contract provides functionality to exchange between SUI and FUN tokens at a fixed rate, with fees collected in the treasury.

### Key Features
- Fixed exchange rate (1 SUI = 100 FUN)
- Fee collection on both swap directions
- Secure token handling
- Error handling for invalid amounts

### Implementation Details

#### Constants
- `EXCHANGE_RATE`: 100 (1 SUI = 100 FUN)
- `BASIS_POINTS_DENOMINATOR`: 10000

#### Error Codes
- `EInvalidAmount`: Invalid amount provided for swap

#### Key Functions
1. `swap_sui_for_fun(store: &mut TreasuryStore, sui_payment: Coin<SUI>, ctx: &mut TxContext): (Coin<FUN>, Coin<SUI>)`
   - Swaps SUI for FUN tokens
   - Collects fees in SUI
   - Returns FUN tokens and remaining SUI

2. `burn_fun_for_sui(store: &mut TreasuryStore, fun_tokens: Coin<FUN>, ctx: &mut TxContext): Coin<SUI>`
   - Burns FUN tokens for SUI
   - Collects fees in FUN
   - Returns equivalent SUI

### Test Suite

The swap contract test suite (`test_swap.move`) includes the following tests:

1. `test_swap_sui_for_fun()`
   - Tests successful SUI to FUN swap
   - Verifies correct exchange rate
   - Checks fee collection

2. `test_burn_fun_for_sui()`
   - Tests successful FUN to SUI swap
   - Verifies correct exchange rate
   - Checks fee collection

3. `test_burn_insufficient_fun()`
   - Tests error handling for insufficient FUN
   - Verifies proper error code
   - Ensures invalid swaps are rejected

4. `test_swap_zero_sui()`
   - Tests error handling for zero SUI
   - Verifies proper error code
   - Ensures invalid swaps are rejected

5. `test_fee_collection()`
   - Tests fee collection during swaps
   - Verifies correct fee amounts
   - Checks both SUI and FUN fee collection

## Testing Best Practices

The test suites follow these best practices:

1. **Setup and Teardown**
   - Uses helper functions for common setup
   - Properly manages resources with `test::return_shared` and `test::end`
   - Maintains clean test state

2. **Transaction Boundaries**
   - Uses `test::next_tx` for proper transaction boundaries
   - Maintains correct sender addresses
   - Handles shared objects appropriately

3. **Assertions**
   - Clear error codes in assertions
   - Comprehensive verification of results
   - Proper error handling tests

4. **Test Organization**
   - Descriptive test names
   - Focused test cases
   - Clear test documentation

## Usage Examples

### Swapping SUI for FUN
```move
let (fun_tokens, remaining_sui) = swap::swap_sui_for_fun(
    &mut treasury_store,
    sui_coins,
    ctx
);
```

### Swapping FUN for SUI
```move
let sui_tokens = swap::burn_fun_for_sui(
    &mut treasury_store,
    fun_coins,
    ctx
);
```

### Collecting Fees
```move
let (sui_fees, fun_fees) = FUN::collect_fees(
    &mut treasury_store,
    ctx
);
```

### Updating Fee Rate
```move
FUN::update_fee(
    &mut treasury_store,
    new_fee_bps
);
``` 
