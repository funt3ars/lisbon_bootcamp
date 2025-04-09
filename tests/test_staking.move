#[test_only]
module contract::test_staking;

use sui::coin;
use sui::test_scenario as ts;

use contract::staking::{Self, StakingPool, EUserHasNoStake};
use contract::gold::GOLD;


const USER: address = @0xCAFE;


#[test]
public fun user_stakes() {
   let mut scenario = ts::begin(USER);
   {
      staking::init_testing(scenario.ctx());
   };

   scenario.next_tx(USER);
   {
    let mut pool = scenario.take_shared<StakingPool>();
    let coin_gold = coin::mint_for_testing<GOLD>(50_000_000_000, scenario.ctx());

    staking::stake(&mut pool, coin_gold, scenario.ctx());

    ts::return_shared(pool);
   };

   scenario.next_tx(USER);
   {
    let pool = scenario.take_shared<StakingPool>();
    assert!(pool.total_staked_amount() == 50_000_000_000);

    ts::return_shared(pool);
   };

   scenario.end();

}

#[test]
#[expected_failure(abort_code=EUserHasNoStake)]
public fun user_tries_to_unstake_without_staking() {
    let mut scenario = ts::begin(USER);
    {
        staking::init_testing(scenario.ctx());
    };

    scenario.next_tx(USER);
   {
    let mut pool = scenario.take_shared<StakingPool>();
    

    let (coin1, coin2) = staking::unstake(
        &mut pool,
        10_000_000_000,
        scenario.ctx()
    );

    transfer::public_transfer(coin1, USER);
    transfer::public_transfer(coin2, USER);
    ts::return_shared(pool);
   };


   scenario.end();
}