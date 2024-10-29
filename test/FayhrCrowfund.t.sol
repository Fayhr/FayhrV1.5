// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/FayhrCrowdfund.sol";
import "../src/TestToken.sol";

contract FayhrCrowdfundTest is Test {
    FayhrCrowdfund private crowdfund;
    TestToken token;
    address private owner = address(this);
    address private user1 = address(1);
    address private user2 = address(2);
    address private user3 = address(3);
    address private feecollector = address(3);

    function setUp() public {
        token = new TestToken();
        crowdfund = new FayhrCrowdfund(address(token), feecollector);

        token.transfer(user1, 115e18);
        token.transfer(user2, 115e18);
    }

    function testCreatePoll() public {
        uint256 subcoopId = 1;
        uint256 crowdfundId = 1;
        string memory name = "Test Crowdfund";
        uint256 requiredYesVotes = 10;
        bool verdict = false;
        bool verdict2 = true;

        crowdfund.createPoll(subcoopId, crowdfundId, name, requiredYesVotes, verdict, verdict2);

        FayhrCrowdfund.CrowdfundType memory createdCrowdfund = crowdfund.getCrowdfund(crowdfundId);

        assertEq(createdCrowdfund.id, crowdfundId);
        assertEq(createdCrowdfund.name, name);
        assertEq(createdCrowdfund.requiredYesVotes, requiredYesVotes);
        assertEq(createdCrowdfund.closed, verdict);
        assertEq(createdCrowdfund.pollClosed, verdict);
    }

    function testVote() public {
        uint256 subcoopId = 1;
        uint256 crowdfundId = 1;
        string memory name = "Test Crowdfund";
        uint256 requiredYesVotes = 1;
        bool verdict = false;
        bool verdict2 = true;

        crowdfund.createPoll(subcoopId, crowdfundId, name, requiredYesVotes, verdict, verdict2);

        vm.prank(user1);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user2);
        crowdfund.vote(crowdfundId, verdict2);

        FayhrCrowdfund.CrowdfundType memory votedCrowdfund = crowdfund.getCrowdfund(crowdfundId);

        assertEq(votedCrowdfund.availableYesVotes, 1);
        assertEq(uint256(votedCrowdfund.authorization), uint256(FayhrCrowdfund.Authorization.active));
    }

    function testDelegateToken() public {
        uint256 subcoopId = 1;
        uint256 crowdfundId = 1;
        uint256 slotUnit = 1;
        uint256 productCost = 100e18;
        uint256 deliveryDividend = 10e18;
        uint256 agencyFee = 5e18;
        uint256 slotHard = 10;
        uint256 slotSoft = 5;
        uint256 startTime = 1;
        uint256 endTime = 10;
        bool verdict = false;
        bool verdict2 = true;

        // Create and start a crowdfund
        vm.prank(user2);
        crowdfund.createPoll(subcoopId, crowdfundId, "Test Crowdfund", 1, verdict, verdict2);

        vm.prank(user1);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user3);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user2);
        crowdfund.startCrowdfund(
            crowdfundId,
            subcoopId,
            productCost,
            deliveryDividend,
            agencyFee,
            slotHard,
            slotSoft,
            startTime,
            endTime,
            verdict
        );
        
        vm.prank(user1);
        // Approve tokens
        token.approve(address(crowdfund), 115e18);


        vm.warp(block.timestamp + 3);

        vm.prank(user1);
        // Delegate tokens
        crowdfund.delegateToken(subcoopId, crowdfundId, slotUnit);

        FayhrCrowdfund.CrowdfundType memory delegateCrowdfund = crowdfund.getCrowdfund(crowdfundId);

        assertEq(delegateCrowdfund.totalContributed, delegateCrowdfund.slot * slotUnit);
    }

    function testClaimToken() public {
        uint256 subcoopId = 1;
        uint256 crowdfundId = 1;
        uint256 slotUnit = 1;
        uint256 productCost = 100e18;
        uint256 deliveryDividend = 10e18;
        uint256 agencyFee = 5e18;
        uint256 slotHard = 10;
        uint256 slotSoft = 5;
        uint256 startTime = 1;
        uint256 endTime = 10;
        bool verdict = false;
        bool verdict2 = true;

        vm.prank(user2);
        // Create and start a crowdfund
        crowdfund.createPoll(subcoopId, crowdfundId, "Test Crowdfund", 1, verdict, verdict2);

        vm.prank(user1);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user3);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user2);
        crowdfund.startCrowdfund(
            crowdfundId,
            subcoopId,
            productCost,
            deliveryDividend,
            agencyFee,
            slotHard,
            slotSoft,
            startTime,
            endTime,
            verdict
        );

        vm.prank(user1);
        // Approve and delegate tokens
        token.approve(address(crowdfund), 115e18);
        uint256 balanceBefore = token.balanceOf(user1);

        vm.warp(block.timestamp + 2);

        vm.prank(user1);
        crowdfund.delegateToken(subcoopId, crowdfundId, slotUnit);
        uint256 balanceAfter = token.balanceOf(user1);

        vm.prank(user2);
        // Close the crowdfund
        crowdfund.cancelCrowdfund(crowdfundId, verdict2);

        // Claim tokens
        vm.prank(user1);
        crowdfund.claimToken(subcoopId, crowdfundId);
        uint256 claimBalance = token.balanceOf(user1);
        
        uint256 delegateBalance = slotUnit * (productCost + deliveryDividend + agencyFee);
        assertEq(balanceAfter, balanceBefore - delegateBalance );
        assertEq(claimBalance, delegateBalance);
    }

    function testWithdrawDivAndProduct() public {
        uint256 subcoopId = 1;
        uint256 crowdfundId = 1;
        uint256 slotUnit = 1;
        uint256 productCost = 100e18;
        uint256 deliveryDividend = 10e18;
        uint256 agencyFee = 5e18;
        uint256 slotHard = 1;
        uint256 slotSoft = 1;
        uint256 startTime = 1;
        uint256 endTime = 10;
        bool verdict = false;
        bool verdict2 = true;

        vm.prank(user2);
        // Create and start a crowdfund
        crowdfund.createPoll(subcoopId, crowdfundId, "Test Crowdfund", 1, verdict, verdict2);

        vm.prank(user1);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user3);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user2);
        crowdfund.startCrowdfund(
            crowdfundId,
            subcoopId,
            productCost,
            deliveryDividend,
            agencyFee,
            slotHard,
            slotSoft,
            startTime,
            endTime,
            verdict
        );
        uint256 firstBalance = token.balanceOf(user2);

        vm.prank(user1);
        // Approve and delegate tokens
        token.approve(address(crowdfund), 1150e18);

        vm.warp(block.timestamp + 5);

        vm.prank(user1);     
        crowdfund.delegateToken(subcoopId, crowdfundId, slotUnit);
        

        vm.warp(block.timestamp + 15);
        // Withdraw Dividends and Product Cost
        vm.prank(user2);
        crowdfund.withdrawDivAndProduct(subcoopId, crowdfundId);

        uint256 balance = token.balanceOf(user2);
        assertEq(balance, firstBalance + ((productCost + deliveryDividend) * slotUnit));
    }

    function testWithdrawContractorFee() public {
        uint256 subcoopId = 1;
        uint256 crowdfundId = 1;
        uint256 slotUnit = 1;
        uint256 productCost = 100e18;
        uint256 deliveryDividend = 10e18;
        uint256 agencyFee = 5e18;
        uint256 slotHard = 1;
        uint256 slotSoft = 1;
        uint256 startTime = 1;
        uint256 endTime = 10;
        bool verdict = false;
        bool verdict2 = true;

        vm.prank(user2);
        // Create and start a crowdfund
        crowdfund.createPoll(subcoopId, crowdfundId, "Test Crowdfund", 1, verdict, verdict2);

        vm.prank(user1);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user3);
        crowdfund.vote(crowdfundId, verdict2);

        vm.prank(user2);
        crowdfund.startCrowdfund(
            crowdfundId,
            subcoopId,
            productCost,
            deliveryDividend,
            agencyFee,
            slotHard,
            slotSoft,
            startTime,
            endTime,
            verdict
        );
        uint256 firstBalance = token.balanceOf(user2);

        vm.prank(user1);
        // Approve and delegate tokens
        token.approve(address(crowdfund), 1150e18);

        vm.warp(block.timestamp + 5);

        vm.prank(user1);
        crowdfund.delegateToken(subcoopId, crowdfundId, slotUnit);

        vm.warp(block.timestamp + 12);

        // Withdraw Dividends and Product Cost
        vm.prank(user2);
        crowdfund.withdrawDivAndProduct(subcoopId, crowdfundId);


        // Permit and Withdraw Contractor Fee
        vm.prank(user1);
        crowdfund.permitFeeWithdrawal(subcoopId, crowdfundId, verdict2);

        vm.prank(user2);
        crowdfund.withdrawContractorFee(subcoopId, crowdfundId);

        uint256 balance = token.balanceOf(user2);
        assertEq(balance, firstBalance + ((productCost + deliveryDividend + (agencyFee / 2)) * slotUnit));
    }
}
