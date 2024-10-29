// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/FayhrGov.sol";

contract FayhrGovTest is Test {
    FayhrGov private fayhrGov;
    address private admin = address(1);
    address private contractor1 = address(2);
    address private contractor2 = address(3); 

    // Initialize the contract before each test
    function setUp() public {
        fayhrGov = new FayhrGov(admin, 604800);
    }

    // Test contract deployment and initial state
    function testDeployment() public view {
        assertEq(fayhrGov.nextSubcoopId(), 0);
        assertEq(fayhrGov.consensusPeriod(), 604800);
    }

    // Test adding a contractor and creating a subcoop
    function testAddContractor() public {
        vm.prank(admin);
        fayhrGov.addContractor(contractor1, 1, "Subcoop 1");
        // FayhrGov.Subcoop memory subcoop = fayhrGov.subcoops(1);
        (uint256 subcoopId, string memory subcoopName, address contractor,,,, uint256 memberCount, FayhrGov.Proposal proposal,) = fayhrGov.subcoops(1);

        assertEq(subcoopId, 1);
        assertEq(subcoopName, "Subcoop 1");
        assertEq(contractor, contractor1);
        assertEq(memberCount, 0);
        assertEq(uint256(proposal), uint256(FayhrGov.Proposal.safe));
    }

    // Test proposing a removal of contractor
    function testProposal() public {
        vm.prank(admin);
        fayhrGov.addContractor(contractor1, 1, "Subcoop 1");

        vm.prank(contractor1);
        fayhrGov.addSubcoopMember(1, true);

        vm.prank(contractor1);
        fayhrGov.proposal(1, 1, "Remove contractor", true);

        // FayhrGov.Subcoop memory subcoop = fayhrGov.subcoops(1);
        (,,,,, uint256 currentProposalId,, FayhrGov.Proposal proposal,) = fayhrGov.subcoops(1);

        assertEq(uint256(proposal), uint256(FayhrGov.Proposal.submitted));
        assertEq(currentProposalId, 1);
    }

    // Test vetoing a proposal
    function testVeto() public {
        vm.prank(admin);
        fayhrGov.addContractor(contractor1, 1, "Subcoop 1");

        vm.prank(contractor1);
        fayhrGov.addSubcoopMember(1, true);

        vm.prank(contractor1);
        fayhrGov.proposal(1, 1, "Remove contractor", true);

        vm.prank(contractor1);
        fayhrGov.veto(1, 1, true);

        // FayhrGov.Subcoop memory subcoop = fayhrGov.subcoops(1);
        (,,, uint256 vetoCount,,,,,) = fayhrGov.subcoops(1);

        assertEq(vetoCount, 1);
        assertEq(fayhrGov.hasVetoed(1, 1, contractor1), true);
    }

    // Test admin vetoing a proposal
    function testAdminVetoProposal() public {
        vm.prank(admin);
        fayhrGov.addContractor(contractor1, 1, "Subcoop 1");

        vm.prank(contractor2);
        fayhrGov.addSubcoopMember(1, true);

        vm.prank(contractor2);
        fayhrGov.proposal(1, 1, "Remove contractor", true);

        vm.prank(contractor2);
        fayhrGov.veto(1, 1, true);


        vm.prank(admin);
        fayhrGov.vetoproposal(1, 1);

        // FayhrGov.Subcoop memory subcoop = fayhrGov.subcoops(1);
        (,, address contractor,,,uint256 currentProposalId,, FayhrGov.Proposal proposal,) = fayhrGov.subcoops(1);
        assertEq(contractor, address(0));
        assertEq(uint256(proposal), uint256(FayhrGov.Proposal.safe));
        assertEq(currentProposalId, 0);
    }

    // Test RemoveContractor function
    function testRemoveContractor() public {
        vm.prank(admin);
        fayhrGov.addContractor(contractor1, 1, "Subcoop 1");

        vm.prank(admin);
        fayhrGov.RemoveContractor(contractor1, 1);

        // FayhrGov.Subcoop memory subcoop = fayhrGov.subcoops(1);
        (,, address contractor,,,,,,) = fayhrGov.subcoops(1);

        assertEq(contractor, address(0));
        assertEq(fayhrGov.contractors(contractor1), 0);
    }

    // Test addContractorAfterVeto function
    function testAddContractorAfterVeto() public {
        vm.prank(admin);
        fayhrGov.addContractor(contractor1, 1, "Subcoop 1");

        vm.prank(admin);
        fayhrGov.RemoveContractor(contractor1, 1);

        vm.prank(admin);
        fayhrGov.addContractorAfterVeto(contractor2, 1);

        // FayhrGov.Subcoop memory subcoop = fayhrGov.subcoops(1);
        (,, address contractor,,,,,,) = fayhrGov.subcoops(1);

        assertEq(contractor, contractor2);
        assertEq(fayhrGov.contractors(contractor2), 1);
    }

    // Test addSubcoopMember function
    function testAddSubcoopMember() public {
        vm.prank(admin);
        fayhrGov.addContractor(contractor1, 1, "Subcoop 1");

        vm.prank(contractor1);
        fayhrGov.addSubcoopMember(1, true);

        assertEq(fayhrGov.memberExists(1, contractor1), true);
        // FayhrGov.Subcoop memory subcoop = fayhrGov.subcoops(1);
        (,,,,,, uint256 memberCount,,) = fayhrGov.subcoops(1);
        assertEq(memberCount, 1); // 1 added member
    }

   /* // Test getConsensus function
    function testGetConsensus() public view {
        uint256 expectedConsensus = 10000 * 2 / 3;
        uint256 actualConsensus = fayhrGov.getConsensus();
        assertEq(actualConsensus, expectedConsensus);
    }

    // Test updateConsensus function
    function testUpdateConsensus() public {
        uint256 newConsensus = 150;

        vm.prank(admin);
        fayhrGov.updateConsensus(newConsensus);

        assertEq(fayhrGov.consensus(), newConsensus);
    }
    */
}

