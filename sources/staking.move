module contract::staking;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::dynamic_field as df;
use sui::sui::SUI;
use sui::table::{Self, Table};

use contract::gold::GOLD;

// Constant
const PRICE_IN_SUI: u64 = 10_000_000_000;
const AMOUNT_OF_GOLD: u64 = 50_000_000_000;
// const ADMIN_ADDRESS: address = @0x38e6bd6c23b8cd9b8ea0e18bd45da43406190df850b1d47614fd573eac41a913;

// Errors 
const ERequestedValueTooHigh: u64 = 0;
const EWrongAmountOfSui: u64 = 1;
const EUserHasNoStake: u64 = 2;
const EAmountTooHigh: u64 = 3;
const ENotEnoughStakedGOLD: u64 = 4;

public struct AdminCap has key, store  {
    id: UID,
}

public struct StakingPool has key, store {
    id: UID,
    coins: Balance<GOLD>,
    rewards: Balance<SUI>,
    staked_amounts: Table<address, u64>,
}


fun init(ctx: &mut TxContext) {
    let pool = StakingPool {
        id: object::new(ctx),
        coins: balance::zero<GOLD>(),
        rewards: balance::zero<SUI>(),
        staked_amounts: table::new<address, u64>(ctx)

    };

    let admin_cap = AdminCap{
        id: object::new(ctx)
    };

    transfer::public_share_object(pool);
    transfer::public_transfer(admin_cap, ctx.sender());
}


public fun stake(pool: &mut StakingPool, coin: Coin<GOLD>, ctx: &mut TxContext) {
    let sender = ctx.sender();
    let amount_staked = coin.value();
    pool.coins.join(coin.into_balance());

    if(pool.staked_amounts.contains<address, u64>(sender)) {
        *pool.staked_amounts.borrow_mut<address, u64>(sender) =
          *pool.staked_amounts.borrow<address, u64>(sender) + amount_staked;
    } else {
        pool.staked_amounts.add(sender, amount_staked);
    };

}


public fun unstake(pool: &mut StakingPool, value: u64, ctx: &mut TxContext): (Coin<GOLD>, Coin<SUI>) {
    let sender = ctx.sender();
    // check if the user has a stake
    assert!(pool.staked_amounts.contains(sender), EUserHasNoStake);
    // check if the amount to unstake is valid
    let staked_amount = *pool.staked_amounts.borrow<address, u64>(sender);
    assert!( staked_amount >= value, ERequestedValueTooHigh);

    if (staked_amount == value) {
        pool.staked_amounts.remove<address, u64>(sender);
    } else {
        *pool.staked_amounts.borrow_mut(sender) = staked_amount - value;
    };

    // calculate rewards
    let reward = pool.rewards.value() * value / pool.coins.value();

    let coin_balance = pool.coins.split(value);
    let sui_balance = pool.rewards.split(reward);
    let gold_coin = coin::from_balance(coin_balance, ctx);
    let sui_coin = sui_balance.into_coin(ctx);

    (gold_coin, sui_coin)
}

public fun exchange_for_sui(pool: &mut StakingPool, coin: Coin<SUI>, ctx: &mut TxContext): Coin<GOLD> {
    assert!(coin.value() == PRICE_IN_SUI, EWrongAmountOfSui);
    assert!(pool.coins.value() >= AMOUNT_OF_GOLD, ENotEnoughStakedGOLD);
    pool.rewards.join(coin.into_balance());

    let coin_balance = pool.coins.split(AMOUNT_OF_GOLD);
    coin_balance.into_coin(ctx)
}


// This is an example of gating functions with a "cap", this function is a very "scam"-like function otherwise
public fun admin_gather_profits(pool: &mut StakingPool, _: &AdminCap, ctx: &mut TxContext): Coin<SUI> {
    let value = pool.rewards.value();
    let coin_balance = pool.rewards.split(value);

    coin_balance.into_coin(ctx)
}


// Accessor
public fun total_staked_amount(pool: &StakingPool): u64 {
    pool.coins.value()
}



// Raw dynamic field example

public fun stake_with_df(pool: &mut StakingPool, coin: Coin<GOLD>, ctx: &mut TxContext) {
    let coin_value = coin.value();
    pool.coins.join(coin.into_balance());

    if(df::exists_(&pool.id, ctx.sender())) {
        *df::borrow_mut<address, u64>(&mut pool.id, ctx.sender()) = 
          *df::borrow(&pool.id, ctx.sender()) + coin_value;
    } else {
        df::add<address, u64>(&mut pool.id, ctx.sender(), coin_value);
    };
    
}

public fun unstake_with_df(pool: &mut StakingPool, amount: u64, ctx: &mut TxContext): Coin<GOLD> {
    let sender = ctx.sender();
    // check if the user exists by checking if we have created a dynamic previously
    assert!(df::exists_(&pool.id, sender), EUserHasNoStake);
    // check if the amount to unstake is less or equal to the amount they have staked
    let amount_staked = *df::borrow<address, u64>(&pool.id, sender);
    assert!(amount_staked >= amount, EAmountTooHigh);
    if(amount_staked == amount) {
        _ = df::remove<address, u64>(&mut pool.id, sender);
    } else {
        *df::borrow_mut<address, u64>(&mut pool.id, sender) = amount_staked - amount;
    };
    // give the unstaked coin to the user
    let coin_balance = pool.coins.split(amount);

    coin_balance.into_coin(ctx)

}




#[test_only]
public fun init_testing(ctx: &mut TxContext) {
    init(ctx);
}

