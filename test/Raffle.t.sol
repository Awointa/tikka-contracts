// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Raffle.sol";
import "../src/MockToken.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    MockERC20 public token;
    MockERC721 public nft;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // Fallback function to receive ETH
    receive() external payable {}

    event RaffleCreated(uint256 indexed raffleId, address indexed creator, string description, uint256 endTime, uint256 maxTickets, bool allowMultipleTickets);
    event TicketPurchased(uint256 indexed raffleId, address indexed buyer, uint256 ticketId, uint256 amount);
    event WinnerSelected(uint256 indexed raffleId, address indexed winner, uint256 ticketId);
    event WinningsWithdrawn(uint256 indexed raffleId, address indexed winner, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        raffle = new Raffle();
        token = new MockERC20("Test Token", "TEST", 18);
        nft = new MockERC721("Test NFT", "TNFT");
        
        // Fund users with ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        
        // Mint tokens to users
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        token.mint(user3, 1000 ether);
        
        // Mint NFTs to users
        nft.mint(user1, 1);
        nft.mint(user2, 2);
        nft.mint(user3, 3);
    }

    function testCreateRaffle() public {
        string memory description = "Test Raffle";
        uint256 endTime = block.timestamp + 1 days;
        uint256 maxTickets = 100;
        bool allowMultipleTickets = true;
        uint256 ticketPrice = 0.1 ether;

        vm.expectEmit(true, true, true, true);
        emit RaffleCreated(1, owner, description, endTime, maxTickets, allowMultipleTickets);
        
        raffle.createRaffle(description, endTime, maxTickets, allowMultipleTickets, ticketPrice, address(0));
        
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertEq(raffleData.id, 1);
        assertEq(raffleData.creator, owner);
        assertEq(raffleData.description, description);
        assertEq(raffleData.endTime, endTime);
        assertEq(raffleData.maxTickets, maxTickets);
        assertEq(raffleData.allowMultipleTickets, allowMultipleTickets);
        assertEq(raffleData.ticketPrice, ticketPrice);
        assertTrue(raffleData.isActive);
    }

    function testCreateRaffleInvalidParams() public {
        // Test invalid end time
        vm.expectRevert("End time must be in the future");
        raffle.createRaffle("Test", block.timestamp - 1, 100, true, 0.1 ether, address(0));
        
        // Test zero max tickets
        vm.expectRevert("Max tickets must be greater than 0");
        raffle.createRaffle("Test", block.timestamp + 1 days, 0, true, 0.1 ether, address(0));
        
        // Test zero ticket price
        vm.expectRevert("Ticket price must be greater than 0");
        raffle.createRaffle("Test", block.timestamp + 1 days, 100, true, 0, address(0));
    }

    function testBuySingleTicket() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy ticket
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit TicketPurchased(1, user1, 1, 0.1 ether);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Check ticket data
        Raffle.Ticket memory ticket = raffle.getTicketData(1);
        assertEq(ticket.id, 1);
        assertEq(ticket.raffleId, 1);
        assertEq(ticket.owner, user1);
        assertFalse(ticket.isWinner);
        
        // Check user tickets
        assertEq(raffle.getUserTicketsInRaffle(1, user1), 1);
        uint256[] memory userTickets = raffle.getUserTicketIds(user1);
        assertEq(userTickets.length, 1);
        assertEq(userTickets[0], 1);
        
        // Check raffle data
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertEq(raffleData.totalTicketsSold, 1);
    }

    function testBuyMultipleTickets() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy multiple tickets
        vm.prank(user1);
        raffle.buyMultipleTickets{value: 0.3 ether}(1, 3);
        
        // Check user tickets
        assertEq(raffle.getUserTicketsInRaffle(1, user1), 3);
        uint256[] memory userTickets = raffle.getUserTicketIds(user1);
        assertEq(userTickets.length, 3);
        
        // Check raffle data
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertEq(raffleData.totalTicketsSold, 3);
    }

    function testBuyTicketInvalidParams() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Test incorrect payment amount
        vm.prank(user1);
        vm.expectRevert("Incorrect ticket price");
        raffle.buyTicket{value: 0.05 ether}(1);
        
        // Test buying from non-existent raffle
        vm.prank(user1);
        vm.expectRevert("Raffle does not exist");
        raffle.buyTicket{value: 0.1 ether}(999);
    }

    function testBuyTicketWhenMultipleNotAllowed() public {
        // Create raffle that doesn't allow multiple tickets
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, false, 0.1 ether, address(0));
        
        // Buy first ticket - should succeed
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Try to buy second ticket - should fail
        vm.prank(user1);
        vm.expectRevert("Multiple tickets not allowed");
        raffle.buyTicket{value: 0.1 ether}(1);
    }

    function testBuyTicketWhenRaffleEnded() public {
        // Create raffle that ends in the future first
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Fast forward time to end the raffle
        vm.warp(block.timestamp + 2 days);
        
        // Try to buy ticket - should fail
        vm.prank(user1);
        vm.expectRevert("Raffle has ended");
        raffle.buyTicket{value: 0.1 ether}(1);
    }

    function testBuyTicketWhenMaxTicketsReached() public {
        // Create raffle with max 1 ticket
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 1, true, 0.1 ether, address(0));
        
        // Buy first ticket
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Try to buy second ticket - should fail
        vm.prank(user2);
        vm.expectRevert("No tickets available");
        raffle.buyTicket{value: 0.1 ether}(1);
    }

    function testSelectWinner() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Fast forward time to end raffle
        vm.warp(block.timestamp + 2 days);
        
        // Select winner
        vm.expectEmit(true, true, true, true);
        emit WinnerSelected(1, user1, 1);
        raffle.selectWinner(1, 1);
        
        // Check raffle data
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertEq(raffleData.winner, user1);
        assertEq(raffleData.winningTicketId, 1);
        assertFalse(raffleData.isActive);
        
        // Check ticket data
        Raffle.Ticket memory ticket = raffle.getTicketData(1);
        assertTrue(ticket.isWinner);
    }

    function testSelectWinnerInvalidParams() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Try to select winner before raffle ends
        vm.expectRevert("Raffle has not ended yet");
        raffle.selectWinner(1, 1);
        
        // Fast forward time
        vm.warp(block.timestamp + 2 days);
        
        // Try to select winner with invalid ticket
        vm.expectRevert("Invalid winning ticket");
        raffle.selectWinner(1, 999);
    }

    function testWithdrawWinnings() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Fast forward time and select winner
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1);
        
        uint256 initialBalance = user1.balance;
        
        // Withdraw winnings
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit WinningsWithdrawn(1, user1, 0.19 ether); // 0.2 ether - 5% service charge = 0.19 ether
        raffle.withdrawWinnings(1);
        
        // Check balance increase
        assertEq(user1.balance, initialBalance + 0.19 ether);
        
        // Check raffle data
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertTrue(raffleData.winningsWithdrawn);
    }

    function testWithdrawWinningsInvalidParams() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy ticket
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Fast forward time and select winner
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1);
        
        // Try to withdraw as non-winner
        vm.prank(user2);
        vm.expectRevert("Only winner can withdraw");
        raffle.withdrawWinnings(1);
        
        // Withdraw as winner
        vm.prank(user1);
        raffle.withdrawWinnings(1);
        
        // Try to withdraw again
        vm.prank(user1);
        vm.expectRevert("Winnings already withdrawn");
        raffle.withdrawWinnings(1);
    }

    function testSetPlatformServiceCharge() public {
        // Test setting new service charge
        raffle.setPlatformServiceCharge(10);
        assertEq(raffle.getPlatformServiceCharge(), 10);
        
        // Test setting invalid service charge
        vm.expectRevert("Service charge cannot exceed 20%");
        raffle.setPlatformServiceCharge(25);
    }

    function testGetRaffleTicketIds() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Get raffle ticket IDs
        uint256[] memory ticketIds = raffle.getRaffleTicketIds(1);
        assertEq(ticketIds.length, 2);
        assertEq(ticketIds[0], 1);
        assertEq(ticketIds[1], 2);
    }

    function testIsRaffleActive() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Should be active
        assertTrue(raffle.isRaffleActive(1));
        
        // Fast forward time
        vm.warp(block.timestamp + 2 days);
        
        // Should not be active
        assertFalse(raffle.isRaffleActive(1));
    }

    function testGetTotalRaffles() public {
        assertEq(raffle.getTotalRaffles(), 0);
        
        // Create raffles
        raffle.createRaffle("Raffle 1", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Raffle 2", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        assertEq(raffle.getTotalRaffles(), 2);
    }

    function testGetContractBalance() public {
        // Create raffle and buy tickets
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        assertEq(raffle.getContractBalance(), 0.2 ether);
    }

    function testCompleteRaffleFlow() public {
        // Create raffle
        raffle.createRaffle("Complete Test Raffle", block.timestamp + 1 days, 10, true, 0.1 ether, address(0));
        
        // Multiple users buy tickets
        vm.prank(user1);
        raffle.buyMultipleTickets{value: 0.3 ether}(1, 3);
        
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        vm.prank(user3);
        raffle.buyMultipleTickets{value: 0.2 ether}(1, 2);
        
        // Check total tickets sold
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertEq(raffleData.totalTicketsSold, 6);
        
        // Fast forward time and select winner
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1); // user1's first ticket wins
        
        // Winner withdraws winnings
        uint256 initialBalance = user1.balance;
        vm.prank(user1);
        raffle.withdrawWinnings(1);
        
        // Check winnings (6 tickets * 0.1 ether = 0.6 ether, minus 5% service charge = 0.57 ether)
        assertEq(user1.balance, initialBalance + 0.57 ether);
    }

    // New token functionality tests
    function testCreateRaffleWithToken() public {
        string memory description = "Token Raffle";
        uint256 endTime = block.timestamp + 1 days;
        uint256 maxTickets = 100;
        bool allowMultipleTickets = true;
        uint256 ticketPrice = 100 ether; // 100 tokens

        raffle.createRaffle(description, endTime, maxTickets, allowMultipleTickets, ticketPrice, address(token));
        
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertEq(raffleData.ticketToken, address(token));
        assertEq(raffleData.ticketPrice, ticketPrice);
    }

    function testBuyTicketWithToken() public {
        // Create token raffle
        raffle.createRaffle("Token Raffle", block.timestamp + 1 days, 100, true, 100 ether, address(token));
        
        // Approve tokens
        vm.prank(user1);
        token.approve(address(raffle), 100 ether);
        
        // Buy ticket with tokens
        vm.prank(user1);
        raffle.buyTicket(1);
        
        // Check ticket was created
        assertEq(raffle.getUserTicketsInRaffle(1, user1), 1);
        
        // Check token balance
        assertEq(token.balanceOf(address(raffle)), 100 ether);
        assertEq(token.balanceOf(user1), 900 ether);
    }

    function testBuyMultipleTicketsWithToken() public {
        // Create token raffle
        raffle.createRaffle("Token Raffle", block.timestamp + 1 days, 100, true, 100 ether, address(token));
        
        // Approve tokens
        vm.prank(user1);
        token.approve(address(raffle), 300 ether);
        
        // Buy multiple tickets
        vm.prank(user1);
        raffle.buyMultipleTickets(1, 3);
        
        // Check tickets were created
        assertEq(raffle.getUserTicketsInRaffle(1, user1), 3);
        
        // Check token balance
        assertEq(token.balanceOf(address(raffle)), 300 ether);
        assertEq(token.balanceOf(user1), 700 ether);
    }

    function testDepositPrizeToken() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("Prize Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Approve tokens for prize
        vm.prank(user1);
        token.approve(address(raffle), 1000 ether);
        
        // Deposit prize
        vm.prank(user1);
        raffle.depositPrizeToken(1, address(token), 1000 ether);
        
        // Check prize data
        Raffle.PrizeData memory prize = raffle.getPrizeData(1);
        assertEq(prize.token, address(token));
        assertEq(prize.amount, 1000 ether);
        assertFalse(prize.isNFT);
        assertTrue(prize.isDeposited);
        
        // Check token balance
        assertEq(token.balanceOf(address(raffle)), 1000 ether);
    }

    function testDepositPrizeNFT() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("NFT Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Approve NFT for prize
        vm.prank(user1);
        nft.approve(address(raffle), 1);
        
        // Deposit NFT prize
        vm.prank(user1);
        raffle.depositPrizeNFT(1, address(nft), 1);
        
        // Check prize data
        Raffle.PrizeData memory prize = raffle.getPrizeData(1);
        assertEq(prize.token, address(nft));
        assertEq(prize.tokenId, 1);
        assertTrue(prize.isNFT);
        assertTrue(prize.isDeposited);
        
        // Check NFT ownership
        assertEq(nft.ownerOf(1), address(raffle));
    }

    function testDepositPrizeETH() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("ETH Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Deposit ETH prize
        vm.prank(user1);
        raffle.depositPrizeETH{value: 1 ether}(1);
        
        // Check prize data
        Raffle.PrizeData memory prize = raffle.getPrizeData(1);
        assertEq(prize.token, address(0));
        assertEq(prize.amount, 1 ether);
        assertFalse(prize.isNFT);
        assertTrue(prize.isDeposited);
        
        // Check ETH balance
        assertEq(address(raffle).balance, 1 ether);
    }

    function testFinalizeRaffleWithTokenPrize() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("Token Prize Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Deposit token prize
        vm.prank(user1);
        token.approve(address(raffle), 1000 ether);
        vm.prank(user1);
        raffle.depositPrizeToken(1, address(token), 1000 ether);
        
        // Buy tickets
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Fast forward time and select winner
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1);
        
        // Finalize raffle
        raffle.finalizeRaffle(1);
        
        // Check token was transferred to winner
        assertEq(token.balanceOf(user2), 2000 ether); // 1000 from setup + 1000 from prize
        
        // Check raffle is finalized
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertTrue(raffleData.isFinalized);
    }

    function testFinalizeRaffleWithNFTPrize() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("NFT Prize Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Deposit NFT prize
        vm.prank(user1);
        nft.approve(address(raffle), 1);
        vm.prank(user1);
        raffle.depositPrizeNFT(1, address(nft), 1);
        
        // Buy tickets
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Fast forward time and select winner
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1);
        
        // Finalize raffle
        raffle.finalizeRaffle(1);
        
        // Check NFT was transferred to winner
        assertEq(nft.ownerOf(1), user2);
        
        // Check raffle is finalized
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertTrue(raffleData.isFinalized);
    }

    function testFinalizeRaffleWithETHPrize() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("ETH Prize Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Deposit ETH prize
        vm.prank(user1);
        raffle.depositPrizeETH{value: 1 ether}(1);
        
        // Buy tickets
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        uint256 initialBalance = user2.balance;
        
        // Fast forward time and select winner
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1);
        
        // Finalize raffle
        raffle.finalizeRaffle(1);
        
        // Check ETH was transferred to winner
        assertEq(user2.balance, initialBalance + 1 ether);
        
        // Check raffle is finalized
        Raffle.RaffleData memory raffleData = raffle.getRaffleData(1);
        assertTrue(raffleData.isFinalized);
    }

    function testPrizeDepositRestrictions() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Try to deposit prize as non-creator
        vm.prank(user2);
        vm.expectRevert("Only raffle creator can deposit prize");
        raffle.depositPrizeETH{value: 1 ether}(1);
        
        // Deposit prize as creator
        vm.prank(user1);
        raffle.depositPrizeETH{value: 1 ether}(1);
        
        // Try to deposit prize again
        vm.prank(user1);
        vm.expectRevert("Prize already deposited");
        raffle.depositPrizeETH{value: 1 ether}(1);
    }

    function testFinalizeRaffleRestrictions() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Try to finalize without winner
        vm.expectRevert("No winner selected");
        raffle.finalizeRaffle(1);
        
        // Buy a ticket first
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Try to finalize without prize
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1);
        vm.expectRevert("No prize deposited");
        raffle.finalizeRaffle(1);
    }

    // ============ GETTER FUNCTION TESTS ============

    function testGetAllRaffleIds() public {
        // Initially no raffles
        uint256[] memory allIds = raffle.getAllRaffleIds();
        assertEq(allIds.length, 0);
        
        // Create some raffles
        raffle.createRaffle("Raffle 1", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Raffle 2", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Raffle 3", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        allIds = raffle.getAllRaffleIds();
        assertEq(allIds.length, 3);
        assertEq(allIds[0], 1);
        assertEq(allIds[1], 2);
        assertEq(allIds[2], 3);
    }

    function testGetRaffleIdsByCreator() public {
        // Create raffles as different users
        vm.prank(user1);
        raffle.createRaffle("User1 Raffle 1", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        vm.prank(user2);
        raffle.createRaffle("User2 Raffle 1", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        vm.prank(user1);
        raffle.createRaffle("User1 Raffle 2", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Get user1's raffles
        uint256[] memory user1Raffles = raffle.getRaffleIdsByCreator(user1);
        assertEq(user1Raffles.length, 2);
        assertEq(user1Raffles[0], 1);
        assertEq(user1Raffles[1], 3);
        
        // Get user2's raffles
        uint256[] memory user2Raffles = raffle.getRaffleIdsByCreator(user2);
        assertEq(user2Raffles.length, 1);
        assertEq(user2Raffles[0], 2);
    }

    function testGetActiveRaffleIds() public {
        // Create raffles
        raffle.createRaffle("Active Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Another Active", block.timestamp + 2 days, 100, true, 0.1 ether, address(0));
        
        uint256[] memory activeIds = raffle.getActiveRaffleIds();
        assertEq(activeIds.length, 2);
        assertEq(activeIds[0], 1);
        assertEq(activeIds[1], 2);
    }

    function testGetEndedRaffleIds() public {
        // Create raffles with future end times first
        raffle.createRaffle("Active Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Future Raffle 1", block.timestamp + 2 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Future Raffle 2", block.timestamp + 3 days, 100, true, 0.1 ether, address(0));
        
        // Fast forward time to make them ended
        vm.warp(block.timestamp + 4 days);
        
        uint256[] memory endedIds = raffle.getEndedRaffleIds();
        assertEq(endedIds.length, 3);
        assertEq(endedIds[0], 1);
        assertEq(endedIds[1], 2);
        assertEq(endedIds[2], 3);
    }

    function testGetRaffleIdsWithPrizes() public {
        // Create raffles
        raffle.createRaffle("No Prize Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        vm.prank(user1);
        raffle.createRaffle("Prize Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Deposit prize for raffle 2
        vm.prank(user1);
        raffle.depositPrizeETH{value: 1 ether}(2);
        
        uint256[] memory prizeIds = raffle.getRaffleIdsWithPrizes();
        assertEq(prizeIds.length, 1);
        assertEq(prizeIds[0], 2);
    }

    function testGetRaffleIdsByTicketToken() public {
        // Create raffles with different tokens
        raffle.createRaffle("ETH Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Token Raffle", block.timestamp + 1 days, 100, true, 100 ether, address(token));
        raffle.createRaffle("Another ETH", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Get ETH raffles
        uint256[] memory ethRaffles = raffle.getRaffleIdsByTicketToken(address(0));
        assertEq(ethRaffles.length, 2);
        assertEq(ethRaffles[0], 1);
        assertEq(ethRaffles[1], 3);
        
        // Get token raffles
        uint256[] memory tokenRaffles = raffle.getRaffleIdsByTicketToken(address(token));
        assertEq(tokenRaffles.length, 1);
        assertEq(tokenRaffles[0], 2);
    }

    function testGetUserRaffleParticipation() public {
        // Create raffle
        raffle.createRaffle("Test Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // User1 buys tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // User2 buys tickets
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Get user1 participation
        (uint256[] memory raffleIds, uint256[] memory ticketCounts) = raffle.getUserRaffleParticipation(user1);
        assertEq(raffleIds.length, 1);
        assertEq(raffleIds[0], 1);
        assertEq(ticketCounts[0], 2);
        
        // Get user2 participation
        (raffleIds, ticketCounts) = raffle.getUserRaffleParticipation(user2);
        assertEq(raffleIds.length, 1);
        assertEq(raffleIds[0], 1);
        assertEq(ticketCounts[0], 1);
    }

    function testGetRaffleStatistics() public {
        // Create raffle as user1
        vm.prank(user1);
        raffle.createRaffle("Stats Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy some tickets
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        vm.prank(user3);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Deposit prize
        vm.prank(user1);
        raffle.depositPrizeETH{value: 1 ether}(1);
        
        // Get statistics
        (
            uint256 totalTicketsSold,
            uint256 totalRevenue,
            uint256 availableTickets,
            uint256 participationCount,
            bool hasPrize,
            bool isEnded,
            bool isFinalized
        ) = raffle.getRaffleStatistics(1);
        
        assertEq(totalTicketsSold, 2);
        assertEq(totalRevenue, 0.2 ether);
        assertEq(availableTickets, 98);
        assertEq(participationCount, 2);
        assertTrue(hasPrize);
        assertFalse(isEnded);
        assertFalse(isFinalized);
    }

    function testGetPlatformStatistics() public {
        // Create some raffles with future end times
        raffle.createRaffle("Raffle 1", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        vm.prank(user1);
        raffle.createRaffle("Raffle 2", block.timestamp + 2 days, 100, true, 0.1 ether, address(0));
        
        // Buy tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(2);
        
        // Deposit prize for raffle 2
        vm.prank(user1);
        raffle.depositPrizeETH{value: 1 ether}(2);
        
        // Fast forward and finalize one raffle
        vm.warp(block.timestamp + 3 days);
        raffle.selectWinner(2, 2); // Use ticket ID 2 (user2's ticket)
        raffle.finalizeRaffle(2);
        
        // Get platform statistics
        (
            uint256 totalRaffles,
            uint256 activeRaffles,
            uint256 endedRaffles,
            uint256 finalizedRaffles,
            uint256 totalTicketsSold,
            uint256 totalRevenue,
            uint256 serviceChargeRate
        ) = raffle.getPlatformStatistics();
        
        assertEq(totalRaffles, 2);
        assertEq(activeRaffles, 0); // Both raffles are ended after time warp
        assertEq(endedRaffles, 2);
        assertEq(finalizedRaffles, 1);
        assertEq(totalTicketsSold, 2);
        assertEq(totalRevenue, 0.2 ether);
        assertEq(serviceChargeRate, 5);
    }

    function testGetRaffleTicketsPaginated() public {
        // Create raffle
        raffle.createRaffle("Pagination Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(1);
        vm.prank(user3);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Get first page (2 tickets)
        (uint256[] memory ticketIds, address[] memory owners, uint256[] memory purchaseTimes) = 
            raffle.getRaffleTicketsPaginated(1, 0, 2);
        
        assertEq(ticketIds.length, 2);
        assertEq(owners.length, 2);
        assertEq(purchaseTimes.length, 2);
        assertEq(ticketIds[0], 1);
        assertEq(ticketIds[1], 2);
        assertEq(owners[0], user1);
        assertEq(owners[1], user2);
        
        // Get second page (1 ticket)
        (ticketIds, owners, purchaseTimes) = raffle.getRaffleTicketsPaginated(1, 2, 2);
        
        assertEq(ticketIds.length, 1);
        assertEq(owners.length, 1);
        assertEq(ticketIds[0], 3);
        assertEq(owners[0], user3);
    }

    function testGetUserTicketsInRaffleDetailed() public {
        // Create raffle
        raffle.createRaffle("Detailed Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // User1 buys multiple tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Get user1's detailed tickets
        (uint256[] memory ticketIds, uint256[] memory purchaseTimes) = 
            raffle.getUserTicketsInRaffleDetailed(1, user1);
        
        assertEq(ticketIds.length, 2);
        assertEq(purchaseTimes.length, 2);
        assertEq(ticketIds[0], 1);
        assertEq(ticketIds[1], 2);
    }

    function testGetRaffleWinners() public {
        // Create raffles
        raffle.createRaffle("Winner Raffle 1", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        raffle.createRaffle("Winner Raffle 2", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // Buy tickets
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        vm.prank(user2);
        raffle.buyTicket{value: 0.1 ether}(2);
        
        // Fast forward and select winners
        vm.warp(block.timestamp + 2 days);
        raffle.selectWinner(1, 1);
        raffle.selectWinner(2, 2);
        
        // Get winners
        (uint256[] memory raffleIds, address[] memory winners) = raffle.getRaffleWinners();
        
        assertEq(raffleIds.length, 2);
        assertEq(winners.length, 2);
        assertEq(raffleIds[0], 1);
        assertEq(raffleIds[1], 2);
        assertEq(winners[0], user1);
        assertEq(winners[1], user2);
    }

    function testGetRaffleByTicketId() public {
        // Create raffle and buy ticket
        raffle.createRaffle("Ticket Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Get raffle by ticket ID
        uint256 raffleId = raffle.getRaffleByTicketId(1);
        assertEq(raffleId, 1);
    }

    function testUserHasTicketsInRaffle() public {
        // Create raffle
        raffle.createRaffle("Ticket Check Raffle", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        // User1 buys ticket
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Check if users have tickets
        assertTrue(raffle.userHasTicketsInRaffle(1, user1));
        assertFalse(raffle.userHasTicketsInRaffle(1, user2));
    }

    function testIndividualGetters() public {
        // Create raffle
        raffle.createRaffle("Individual Test", block.timestamp + 1 days, 50, false, 0.2 ether, address(token));
        
        // Test individual getters
        assertEq(raffle.getRaffleEndTime(1), block.timestamp + 1 days);
        assertEq(raffle.getRaffleCreator(1), owner);
        assertEq(raffle.getRaffleTicketPrice(1), 0.2 ether);
        assertEq(raffle.getRaffleTicketToken(1), address(token));
        assertEq(raffle.getRaffleMaxTickets(1), 50);
        assertEq(raffle.getRaffleDescription(1), "Individual Test");
        assertEq(raffle.getRaffleWinner(1), address(0));
        assertEq(raffle.getRaffleWinningTicketId(1), 0);
        assertFalse(raffle.isRaffleFinalized(1));
        assertEq(raffle.getNextRaffleId(), 2);
        assertEq(raffle.getNextTicketId(), 1);
        assertEq(raffle.getPlatformOwner(), owner);
    }

    function testGetContractTokenBalance() public {
        // Test ETH balance
        uint256 ethBalance = raffle.getContractTokenBalance(address(0));
        assertEq(ethBalance, 0);
        
        // Create raffle and buy ticket
        raffle.createRaffle("Balance Test", block.timestamp + 1 days, 100, true, 0.1 ether, address(0));
        
        vm.prank(user1);
        raffle.buyTicket{value: 0.1 ether}(1);
        
        // Check ETH balance
        ethBalance = raffle.getContractTokenBalance(address(0));
        assertEq(ethBalance, 0.1 ether);
        
        // Check token balance
        uint256 tokenBalance = raffle.getContractTokenBalance(address(token));
        assertEq(tokenBalance, 0);
    }
}
