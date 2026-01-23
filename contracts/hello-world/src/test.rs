#![cfg(test)]

use super::*;
use soroban_sdk::{
    testutils::{Address as _, Events},
    token, Address, Env, String,
};

#[test]
fn test_basic_raffle_flow() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_client = token::Client::new(&env, &token_id);
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&creator, &1_000);
    token_admin_client.mint(&buyer, &1_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Demo Raffle"),
        &0u64,
        &10u32,
        &false,
        &10i128,
        &token_id,
        &100i128,
    );

    client.deposit_prize(&raffle_id);
    client.buy_ticket(&raffle_id, &buyer);
    let winner = client.finalize_raffle(&raffle_id);
    let claimed_amount = client.claim_prize(&raffle_id, &winner);

    let winner_balance = token_client.balance(&winner);
    let creator_balance = token_client.balance(&creator);

    assert_eq!(claimed_amount, 100i128);
    assert_eq!(winner_balance, 1_090);
    assert_eq!(creator_balance, 900);
}

#[test]
fn test_buy_tickets_single() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_client = token::Client::new(&env, &token_id);
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&buyer, &1_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Test Raffle"),
        &1000u64,
        &100u32,
        &true,
        &10i128,
        &token_id,
        &100i128,
    );

    let initial_balance = token_client.balance(&buyer);
    let tickets_sold = client.buy_tickets(&raffle_id, &buyer, &1u32);
    let final_balance = token_client.balance(&buyer);
    let raffle = client.get_raffle(&raffle_id);

    assert_eq!(tickets_sold, 1);
    assert_eq!(raffle.tickets_sold, 1);
    assert_eq!(initial_balance - final_balance, 10); // 1 ticket × 10 price
}

#[test]
fn test_buy_tickets_multiple() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_client = token::Client::new(&env, &token_id);
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&buyer, &10_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Test Raffle"),
        &1000u64,
        &100u32,
        &true,
        &10i128,
        &token_id,
        &100i128,
    );

    let quantity = 5u32;
    let initial_balance = token_client.balance(&buyer);
    let tickets_sold = client.buy_tickets(&raffle_id, &buyer, &quantity);
    let final_balance = token_client.balance(&buyer);
    let raffle = client.get_raffle(&raffle_id);
    let tickets = client.get_tickets(&raffle_id);

    assert_eq!(tickets_sold, quantity);
    assert_eq!(raffle.tickets_sold, quantity);
    assert_eq!(initial_balance - final_balance, (quantity as i128) * 10); // 5 tickets × 10 price = 50
    assert_eq!(tickets.len(), quantity);
}

#[test]
fn test_buy_tickets_large_quantity() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_client = token::Client::new(&env, &token_id);
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&buyer, &100_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Test Raffle"),
        &1000u64,
        &100u32,
        &true,
        &10i128,
        &token_id,
        &100i128,
    );

    let quantity = 100u32;
    let initial_balance = token_client.balance(&buyer);
    let tickets_sold = client.buy_tickets(&raffle_id, &buyer, &quantity);
    let final_balance = token_client.balance(&buyer);
    let raffle = client.get_raffle(&raffle_id);

    assert_eq!(tickets_sold, quantity);
    assert_eq!(raffle.tickets_sold, quantity);
    assert_eq!(initial_balance - final_balance, (quantity as i128) * 10); // 100 tickets × 10 price = 1000
}

#[test]
#[should_panic(expected = "multiple_tickets_not_allowed")]
fn test_buy_tickets_allow_multiple_false_rejects_multiple() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&buyer, &1_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Test Raffle"),
        &1000u64,
        &100u32,
        &false, // allow_multiple = false
        &10i128,
        &token_id,
        &100i128,
    );

    // Should panic because allow_multiple is false and quantity > 1
    client.buy_tickets(&raffle_id, &buyer, &5u32);
}

#[test]
#[should_panic(expected = "insufficient_tickets_available")]
fn test_buy_tickets_exceeds_max() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&buyer, &10_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Test Raffle"),
        &1000u64,
        &10u32, // max_tickets = 10
        &true,
        &10i128,
        &token_id,
        &100i128,
    );

    // Should panic because quantity (15) exceeds max_tickets (10)
    client.buy_tickets(&raffle_id, &buyer, &15u32);
}

#[test]
#[should_panic(expected = "quantity_zero")]
fn test_buy_tickets_zero_quantity() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&buyer, &1_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Test Raffle"),
        &1000u64,
        &10u32,
        &true,
        &10i128,
        &token_id,
        &100i128,
    );

    // Should panic because quantity is zero
    client.buy_tickets(&raffle_id, &buyer, &0u32);
}

#[test]
fn test_buy_tickets_allow_multiple_true_allows_multiple() {
    let env = Env::default();
    env.mock_all_auths();

    let creator = Address::generate(&env);
    let buyer = Address::generate(&env);

    let token_admin = Address::generate(&env);
    let token_contract = env.register_stellar_asset_contract_v2(token_admin.clone());
    let token_id = token_contract.address();
    let token_client = token::Client::new(&env, &token_id);
    let token_admin_client = token::StellarAssetClient::new(&env, &token_id);

    token_admin_client.mint(&buyer, &10_000);

    let contract_id = env.register(Contract, ());
    let client = ContractClient::new(&env, &contract_id);

    let raffle_id = client.create_raffle(
        &creator,
        &String::from_str(&env, "Test Raffle"),
        &1000u64,
        &100u32,
        &true, // allow_multiple = true
        &10i128,
        &token_id,
        &100i128,
    );

    // First purchase
    let tickets_sold_1 = client.buy_tickets(&raffle_id, &buyer, &3u32);
    assert_eq!(tickets_sold_1, 3);

    // Second purchase from same buyer should work
    let tickets_sold_2 = client.buy_tickets(&raffle_id, &buyer, &2u32);
    assert_eq!(tickets_sold_2, 5);

    let raffle = client.get_raffle(&raffle_id);
    assert_eq!(raffle.tickets_sold, 5);

    let initial_balance = token_client.balance(&buyer);
    assert_eq!(initial_balance, 10_000 - (5 * 10)); // 5 tickets × 10 price = 50
}

#[test]
fn test_raffle_created_event_emits_with_all_fields() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register_contract(None, Contract);
    let client = ContractClient::new(&env, &contract_id);

    let creator = Address::generate(&env);
    let payment_token = Address::generate(&env);
    let description = String::from_str(&env, "Test Raffle Event");
    let end_time = 1000u64;
    let max_tickets = 100u32;
    let ticket_price = 10i128;
    let prize_amount = 500i128;

    // Create raffle
    let raffle_id = client.create_raffle(
        &creator,
        &description,
        &end_time,
        &max_tickets,
        &true,
        &ticket_price,
        &payment_token,
        &prize_amount,
    );

    // Get events
    let events = env.events().all();

    // Verify event was emitted
    assert!(events.len() > 0);

    // Find the RaffleCreated event
    let event = events.iter().find(|e| {
        e.topics.get(0).unwrap() == Symbol::new(&env, "RaffleCreated").into_val(&env)
    }).expect("RaffleCreated event not found");

    // Verify event topic contains raffle_id
    assert_eq!(event.topics.get(1).unwrap(), raffle_id.into_val(&env));

    // Verify event data
    let event_data: RaffleCreated = event.data.clone().try_into_val(&env).unwrap();
    assert_eq!(event_data.raffle_id, raffle_id);
    assert_eq!(event_data.creator, creator);
    assert_eq!(event_data.end_time, end_time);
    assert_eq!(event_data.max_tickets, max_tickets);
    assert_eq!(event_data.ticket_price, ticket_price);
    assert_eq!(event_data.payment_token, payment_token);
    assert_eq!(event_data.description, description);
}

#[test]
fn test_raffle_created_event_data_matches_parameters() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register_contract(None, Contract);
    let client = ContractClient::new(&env, &contract_id);

    let creator = Address::generate(&env);
    let payment_token = Address::generate(&env);
    let description = String::from_str(&env, "Match Test Raffle");
    let end_time = 5000u64;
    let max_tickets = 250u32;
    let ticket_price = 25i128;
    let prize_amount = 1000i128;

    // Create raffle
    let raffle_id = client.create_raffle(
        &creator,
        &description,
        &end_time,
        &max_tickets,
        &false,
        &ticket_price,
        &payment_token,
        &prize_amount,
    );

    // Verify stored raffle matches event data
    let raffle = client.get_raffle(&raffle_id);
    let events = env.events().all();

    let event = events.iter().find(|e| {
        e.topics.get(0).unwrap() == Symbol::new(&env, "RaffleCreated").into_val(&env)
    }).unwrap();

    let event_data: RaffleCreated = event.data.clone().try_into_val(&env).unwrap();

    // Verify event data matches both input parameters and stored raffle
    assert_eq!(event_data.raffle_id, raffle.id);
    assert_eq!(event_data.creator, raffle.creator);
    assert_eq!(event_data.end_time, raffle.end_time);
    assert_eq!(event_data.max_tickets, raffle.max_tickets);
    assert_eq!(event_data.ticket_price, raffle.ticket_price);
    assert_eq!(event_data.payment_token, raffle.payment_token);
    assert_eq!(event_data.description, raffle.description);
}

#[test]
fn test_raffle_created_event_emits_for_edge_cases() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register_contract(None, Contract);
    let client = ContractClient::new(&env, &contract_id);

    let creator = Address::generate(&env);
    let payment_token = Address::generate(&env);

    // Test with minimum valid values
    let min_description = String::from_str(&env, "A");
    let min_end_time = 1u64;
    let min_max_tickets = 1u32;
    let min_ticket_price = 1i128;
    let min_prize_amount = 1i128;

    let raffle_id_min = client.create_raffle(
        &creator,
        &min_description,
        &min_end_time,
        &min_max_tickets,
        &false,
        &min_ticket_price,
        &payment_token,
        &min_prize_amount,
    );

    // Verify event emitted for minimum values
    let events_min = env.events().all();
    let event_min = events_min.iter().find(|e| {
        e.topics.get(0).unwrap() == Symbol::new(&env, "RaffleCreated").into_val(&env) &&
        e.topics.get(1).unwrap() == raffle_id_min.into_val(&env)
    }).expect("Event not found for minimum values");

    let event_data_min: RaffleCreated = event_min.data.clone().try_into_val(&env).unwrap();
    assert_eq!(event_data_min.max_tickets, min_max_tickets);
    assert_eq!(event_data_min.ticket_price, min_ticket_price);

    // Test with maximum valid values
    let max_description = String::from_str(&env, "Very long description with lots of text to test maximum length handling in event emission");
    let max_end_time = u64::MAX;
    let max_max_tickets = u32::MAX;
    let max_ticket_price = i128::MAX;
    let max_prize_amount = i128::MAX;

    let raffle_id_max = client.create_raffle(
        &creator,
        &max_description,
        &max_end_time,
        &max_max_tickets,
        &true,
        &max_ticket_price,
        &payment_token,
        &max_prize_amount,
    );

    // Verify event emitted for maximum values
    let events_max = env.events().all();
    let event_max = events_max.iter().find(|e| {
        e.topics.get(0).unwrap() == Symbol::new(&env, "RaffleCreated").into_val(&env) &&
        e.topics.get(1).unwrap() == raffle_id_max.into_val(&env)
    }).expect("Event not found for maximum values");

    let event_data_max: RaffleCreated = event_max.data.clone().try_into_val(&env).unwrap();
    assert_eq!(event_data_max.max_tickets, max_max_tickets);
    assert_eq!(event_data_max.ticket_price, max_ticket_price);
    assert_eq!(event_data_max.end_time, max_end_time);
}

#[test]
fn test_multiple_raffles_emit_separate_events() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register_contract(None, Contract);
    let client = ContractClient::new(&env, &contract_id);

    let creator1 = Address::generate(&env);
    let creator2 = Address::generate(&env);
    let payment_token = Address::generate(&env);

    // Create first raffle
    let desc1 = String::from_str(&env, "First Raffle");
    let raffle_id_1 = client.create_raffle(
        &creator1,
        &desc1,
        &1000u64,
        &50u32,
        &true,
        &10i128,
        &payment_token,
        &500i128,
    );

    // Create second raffle
    let desc2 = String::from_str(&env, "Second Raffle");
    let raffle_id_2 = client.create_raffle(
        &creator2,
        &desc2,
        &2000u64,
        &100u32,
        &false,
        &20i128,
        &payment_token,
        &1000i128,
    );

    // Create third raffle
    let desc3 = String::from_str(&env, "Third Raffle");
    let raffle_id_3 = client.create_raffle(
        &creator1,
        &desc3,
        &3000u64,
        &75u32,
        &true,
        &15i128,
        &payment_token,
        &750i128,
    );

    // Get all events
    let events = env.events().all();

    // Filter RaffleCreated events
    let raffle_created_events: Vec<_> = events.iter()
        .filter(|e| e.topics.get(0).unwrap() == Symbol::new(&env, "RaffleCreated").into_val(&env))
        .collect();

    // Verify we have exactly 3 RaffleCreated events
    assert_eq!(raffle_created_events.len(), 3);

    // Verify each event has correct raffle_id in topics
    let event_1 = raffle_created_events.iter()
        .find(|e| e.topics.get(1).unwrap() == raffle_id_1.into_val(&env))
        .expect("Event for raffle 1 not found");
    let event_2 = raffle_created_events.iter()
        .find(|e| e.topics.get(1).unwrap() == raffle_id_2.into_val(&env))
        .expect("Event for raffle 2 not found");
    let event_3 = raffle_created_events.iter()
        .find(|e| e.topics.get(1).unwrap() == raffle_id_3.into_val(&env))
        .expect("Event for raffle 3 not found");

    // Verify event data for each raffle
    let event_data_1: RaffleCreated = event_1.data.clone().try_into_val(&env).unwrap();
    assert_eq!(event_data_1.raffle_id, raffle_id_1);
    assert_eq!(event_data_1.creator, creator1);
    assert_eq!(event_data_1.description, desc1);

    let event_data_2: RaffleCreated = event_2.data.clone().try_into_val(&env).unwrap();
    assert_eq!(event_data_2.raffle_id, raffle_id_2);
    assert_eq!(event_data_2.creator, creator2);
    assert_eq!(event_data_2.description, desc2);

    let event_data_3: RaffleCreated = event_3.data.clone().try_into_val(&env).unwrap();
    assert_eq!(event_data_3.raffle_id, raffle_id_3);
    assert_eq!(event_data_3.creator, creator1);
    assert_eq!(event_data_3.description, desc3);

    // Verify raffle IDs are sequential
    assert_eq!(raffle_id_1, 0);
    assert_eq!(raffle_id_2, 1);
    assert_eq!(raffle_id_3, 2);
}

#[test]
fn test_event_provides_sufficient_indexing_data() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register_contract(None, Contract);
    let client = ContractClient::new(&env, &contract_id);

    let creator = Address::generate(&env);
    let payment_token = Address::generate(&env);
    let description = String::from_str(&env, "Indexing Test Raffle");
    let end_time = 10000u64;
    let max_tickets = 500u32;
    let ticket_price = 50i128;
    let prize_amount = 5000i128;

    let raffle_id = client.create_raffle(
        &creator,
        &description,
        &end_time,
        &max_tickets,
        &true,
        &ticket_price,
        &payment_token,
        &prize_amount,
    );

    let events = env.events().all();
    let event = events.iter().find(|e| {
        e.topics.get(0).unwrap() == Symbol::new(&env, "RaffleCreated").into_val(&env)
    }).unwrap();

    let event_data: RaffleCreated = event.data.clone().try_into_val(&env).unwrap();

    // Verify event contains all critical data for frontend indexing:

    // 1. Unique identifier
    assert!(event_data.raffle_id >= 0);

    // 2. Creator for filtering by user
    assert_eq!(event_data.creator, creator);

    // 3. Time-based filtering
    assert_eq!(event_data.end_time, end_time);

    // 4. Availability information
    assert_eq!(event_data.max_tickets, max_tickets);

    // 5. Pricing information
    assert_eq!(event_data.ticket_price, ticket_price);

    // 6. Payment token for multi-token filtering
    assert_eq!(event_data.payment_token, payment_token);

    // 7. Human-readable description
    assert_eq!(event_data.description, description);

    // All essential fields present - frontend can:
    // - Display raffle card with all info without additional queries
    // - Filter by creator, token, price range, or end time
    // - Sort by end_time or raffle_id
    // - Calculate availability percentage
}
