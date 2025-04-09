module contract::gold;

use sui::coin::{Self, Coin, TreasuryCap};
use sui::url;

use std::ascii;



public struct GOLD has drop {}



fun init(otw: GOLD, ctx: &mut TxContext) {
    let decimals: u8 = 9;
    let symbol: vector<u8> = b"GOLD";
    let name: vector<u8> = b"GOLD";
    let description: vector<u8> = b"This is a very valuable coin";
    let icon = url::new_unsafe(ascii::string(b"https://img.png"));
    let (treasury_cap, metadata) = coin::create_currency<GOLD>(
        otw,
        decimals,
        symbol,
        name,
        description,
        option::some(icon),
        ctx
    );

    transfer::public_transfer(treasury_cap, ctx.sender());
    transfer::public_freeze_object(metadata);
}

public fun mint(t_cap: &mut TreasuryCap<GOLD>, value: u64, ctx: &mut TxContext): Coin<GOLD> {
    coin::mint(t_cap, value, ctx)
}

public fun burn(t_cap: &mut TreasuryCap<GOLD>, coin: Coin<GOLD>) {
    coin::burn(t_cap, coin);
}



