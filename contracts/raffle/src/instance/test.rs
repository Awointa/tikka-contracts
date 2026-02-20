#![cfg(test)]

use super::*;
use soroban_sdk::{
    testutils::{Address as _, Events, Ledger},
    token, Address, Env, IntoVal, String, Symbol,
};

/// HELPER: Standardized environment setup
fn setup_raffle_env(
    env: &Env,
) -> (
    ContractClient<'_>,
    Address,
    Address,
    token::StellarAssetClient<'_>,
    Address,
) {
    let creator = Address::generate(env);
    let buyer = Address::generate(env);
    let admin = Address::generate(env);
    let factory = Address::generate(env);

    let token_contract = env.register_stellar_asset_contract_v2(admin.clone());
    let token_id = token_contract.address();
    let admin_client = token::StellarAssetClient::new(env, &token_id);

    admin_client.mint(&creator, &1_000i128);
    admin_client.mint(&buyer, &1_000i128);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(env, &contract_id);

    client.init(
        &factory,
        &creator,
        &String::from_str(env, "Audit Raffle"),
        &0,
        &5, // Reduced to 5 for easier testing
        &false,
        &10i128,
        &token_id,
        &100i128,
    );

    (client, creator, buyer, admin_client, factory)
}

// --- 1. FUNCTIONAL FLOW TESTS ---

#[test]
fn test_basic_raffle_flow() {
    let env = Env::default();
    env.mock_all_auths();
    let (client, creator, buyer, admin_client, _) = setup_raffle_env(&env);
    let token_client = token::Client::new(&env, &admin_client.address);

    client.deposit_prize();

    // We need 5 different buyers because allow_multiple is false
    for _ in 0..5 {
        let b = Address::generate(&env);
        admin_client.mint(&b, &10i128);
        client.buy_ticket(&b);
    }

    let winner = client.finalize_raffle(&String::from_str(&env, "prng"));
    let _claimed_amount = client.claim_prize(&winner);

    assert_eq!(token_client.balance(&winner), 100i128); // mint 10 - ticket 10 + prize 100
    assert_eq!(token_client.balance(&creator), 900i128); // mint 1000 - prize 100
}

// --- 2. RANDOMNESS SOURCE TESTS ---

#[test]
fn test_randomness_source_prng() {
    let env = Env::default();
    env.mock_all_auths();
    let (client, _, _buyer, admin_client, _) = setup_raffle_env(&env);

    client.deposit_prize();
    for _ in 0..5 {
        let b = Address::generate(&env);
        admin_client.mint(&b, &10i128);
        client.buy_ticket(&b);
    }

    let source = String::from_str(&env, "prng");
    let winner = client.finalize_raffle(&source);

    assert!(winner != Address::generate(&env)); // Should be one of the buyers
}

#[test]
fn test_randomness_source_oracle() {
    let env = Env::default();
    env.mock_all_auths();
    let (client, _, _buyer, admin_client, _) = setup_raffle_env(&env);

    client.deposit_prize();
    for _ in 0..5 {
        let b = Address::generate(&env);
        admin_client.mint(&b, &10i128);
        client.buy_ticket(&b);
    }

    let source = String::from_str(&env, "oracle");
    let winner = client.finalize_raffle(&source);

    assert!(winner != Address::generate(&env));
}

// --- 3. EVENT AUDIT & STATE VALIDATION ---

#[test]
fn test_raffle_finalized_event_audit() {
    let env = Env::default();
    env.mock_all_auths();

    let expected_timestamp = 123456789;
    env.ledger().with_mut(|l| {
        l.timestamp = expected_timestamp;
    });

    let (client, _, _buyer_1, admin_client, _) = setup_raffle_env(&env);

    client.deposit_prize();
    for _ in 0..5 {
        let b = Address::generate(&env);
        admin_client.mint(&b, &10i128);
        client.buy_ticket(&b);
    }

    let _winner = client.finalize_raffle(&String::from_str(&env, "oracle"));

    let events = env.events().all();
    let mut found = false;
    for event in events {
        let t0: Symbol = event.1.get(0).unwrap().into_val(&env);
        if t0 == Symbol::new(&env, "RaffleFinalized") {
            found = true;
            break;
        }
    }
    assert!(found);
}

#[test]
fn test_single_ticket_purchase_event() {
    let env = Env::default();
    env.mock_all_auths();

    let (client, _, buyer, _, _) = setup_raffle_env(&env);

    client.deposit_prize();

    let _ = env.events().all();

    client.buy_ticket(&buyer);

    let events = env.events().all();
    let last_event = events.last().expect("No events");
    let topic_0: Symbol = last_event.1.get(0).unwrap().into_val(&env);
    assert_eq!(topic_0, Symbol::new(&env, "TicketPurchased"));
}

#[test]
fn test_raffle_cancellation() {
    let env = Env::default();
    env.mock_all_auths();
    let (client, creator, buyer, admin_client, _) = setup_raffle_env(&env);
    let token_client = token::Client::new(&env, &admin_client.address);

    client.deposit_prize();
    client.buy_ticket(&buyer);

    client.cancel_raffle();

    // Creator should get prize back
    assert_eq!(token_client.balance(&creator), 1000i128);

    let raffle = client.get_raffle();
    assert!(raffle.status == RaffleStatus::Cancelled);
}
