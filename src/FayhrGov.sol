// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


contract FayhrGov {

    // State Variable
    address payable private admin;
    uint256 public nextSubcoopId;
    uint256 public consensusPeriod;  // 604800 Seconds
    

    // Enums
    enum Proposal {
        safe,
        submitted
    }

   
    // Structs
    struct Subcoop {
        uint256 subcoopId;
        string subcoopName;
        address contractor;
        uint256 vetoCount;
        uint256 proposalId;
        uint256 currentProposalId;
        uint256 memberCount;
        Proposal proposal;
        uint256 consensusEnds;
    }

    
    // Mappings
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasVetoed;
    mapping(uint256 => mapping(uint256 => bool)) public hasProposed;
    mapping(uint256 => Subcoop) public subcoops;
    mapping(address => uint256) public contractors;
    mapping(uint256 => mapping(uint256 => address)) public subcoopMembers;
    mapping(uint256 => mapping(address => bool)) public memberExists;


    // Events
    event SubcoopCreated(address firstContractor, uint256 SubcoopId, string SubcoopName);
    event ProposalSubmitted(uint256 Id, string Removalreason, address proposer);
    event VetoResults(uint256 Id, uint256 ProposalNumber, address Result);
    event ContractorRemoved(uint256 Id, address OldContractor);
    event ContractorAdded(uint256 Id, address NewContractor);
    event ProposalVetoed(uint256 Id, address by);
    

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only Admin can use this function");
        _;
    }


    modifier onlyContractors() {
        require(contractors[msg.sender] != 0, "You Are Not A Contractor");
        _;
    }

    modifier onlySubcoopAuth(uint256 _subcoopId) {
        require(subcoops[_subcoopId].contractor == address(msg.sender), "This is Not Your Subcoop");
        _;
    }

    
    // Constructor
    constructor(address _admin, uint256 _consensusPeriod) {
        admin = payable(_admin);
        consensusPeriod = _consensusPeriod;
    }
    
    
    // Functions
    function proposal(uint256 _subcoopId, uint256 proposeId,  string memory reason, bool verdict) external {
        require(_subcoopId > 0 && proposeId > 0, "Wrong ID Parameters");
        require(memberExists[_subcoopId][address(msg.sender)], "Not A SubCoop Member Here");
        require(!hasProposed[_subcoopId][proposeId], "A Proposal Was Made With This ID");
        Subcoop memory subcoop = subcoops[_subcoopId];
        require(subcoop.proposal == Proposal.safe, "There's Already A Removal Proposal");
        if (subcoop.proposalId == 0) {
            subcoop.proposalId++;
            uint256 count;
            count = subcoop.proposalId;
            hasProposed[_subcoopId][count] = verdict; // Veridct Must Be True
            subcoop.proposal = Proposal.submitted;
            subcoop.currentProposalId = count;
            subcoop.consensusEnds = block.timestamp + consensusPeriod;
            subcoop.proposalId++;
        } else if (subcoop.proposalId > 0) {
            uint256 count;
            count = subcoop.proposalId;
            hasProposed[_subcoopId][count] = verdict; // Veridct Must Be True
            subcoop.proposal = Proposal.submitted;
            subcoop.currentProposalId = count;
            subcoop.consensusEnds = block.timestamp + consensusPeriod;
            subcoop.proposalId++; 
        }
        subcoops[_subcoopId] = subcoop;
        emit ProposalSubmitted(_subcoopId, reason, address(msg.sender));
    }

    function veto(uint256 _subcoopId, uint256 proposeId, bool verdict) external {
        require(_subcoopId > 0 && proposeId > 0, "Wrong ID Parameters");
        require(memberExists[_subcoopId][address(msg.sender)], "Not A SubCoop Member Here");
        Subcoop memory subcoop = subcoops[_subcoopId];
        require(subcoop.proposal == Proposal.submitted, "There's No Removal Proposal");
        require(subcoop.consensusEnds != block.timestamp, "Veto Period Has Ended");
        require(!hasVetoed[_subcoopId][proposeId][address(msg.sender)], "You Have Already Vetoed This Proposal");
        hasVetoed[_subcoopId][proposeId][address(msg.sender)] = verdict; // Verdict must be true
        subcoop.vetoCount++;
        subcoops[_subcoopId] = subcoop;
        emit ProposalVetoed(_subcoopId, address(msg.sender));
    }

    function vetoproposal(uint256 _subcoopId, uint256 proposeId) external onlyAdmin {
        require(_subcoopId > 0 && proposeId > 0, "Wrong ID Parameters");
        Subcoop memory subcoop = subcoops[_subcoopId];
        require(subcoop.currentProposalId == proposeId, "This Proposal Has Been Concluded");
        require(subcoop.proposal == Proposal.submitted, "Proposal Already Vetoed or Has Been Made");
        require(subcoop.consensusEnds > block.timestamp, "Veto Period Not Ended Yet");
        uint256 vetoDeterminant = subcoop.memberCount;
        if (subcoop.vetoCount == vetoDeterminant) {
            subcoop.contractor = address(0);
            subcoop.vetoCount = 0;
            subcoop.proposal = Proposal.safe;
            subcoop.currentProposalId = 0;
        } else if (subcoop.vetoCount < vetoDeterminant) {
            subcoop.vetoCount = 0;
            subcoop.proposal = Proposal.safe;
            subcoop.currentProposalId = 0;
        }
        subcoops[_subcoopId] = subcoop;
        emit VetoResults(_subcoopId, proposeId, subcoop.contractor);
    }

    function addContractor(address _contractor, uint256 _subcoopId, string memory _subcoopName) external onlyAdmin {
        require(_subcoopId > 0, "Invalid Subcoop ID!");
        require(subcoops[_subcoopId].subcoopId == 0, "Subcoop ID already exists!");
        uint256 newSubcoopId;
        if (nextSubcoopId == 0) {
            nextSubcoopId++;
            newSubcoopId = nextSubcoopId;
            nextSubcoopId++;
        } else if (nextSubcoopId > 0) {
            newSubcoopId = nextSubcoopId;
            nextSubcoopId++;
        }
        Subcoop storage newSubcoop = subcoops[newSubcoopId];
        newSubcoop.subcoopId = newSubcoopId;
        newSubcoop.subcoopName = _subcoopName;
        newSubcoop.contractor = _contractor;
        newSubcoop.vetoCount = 0;
        newSubcoop.proposalId = 0;
        newSubcoop.currentProposalId = 0;
        newSubcoop.memberCount = 0;
        newSubcoop.proposal = Proposal.safe;
        newSubcoop.consensusEnds = 0;
        contractors[_contractor] += 1;
        emit SubcoopCreated(_contractor, newSubcoopId, _subcoopName);
    }

    function RemoveContractor(address _contractor, uint256 _subcoopId) external onlyAdmin {
       require(_subcoopId > 0, "Invalid Subcoop ID!");
       require(contractors[_contractor] != 0, "This User Is Not A Contractor");
       require(subcoops[_subcoopId].subcoopId != 0, "Subcoop ID Doesn't Exists!");
       Subcoop memory subcoop = subcoops[_subcoopId];
       subcoop.contractor = address(0);
       contractors[_contractor] = 0;
       subcoops[_subcoopId] = subcoop;
       emit ContractorRemoved(_subcoopId, _contractor);
    }

    function addContractorAfterVeto(address newContractor, uint256 _subcoopId) external onlyAdmin {
        require(_subcoopId > 0, "Invalid Subcoop ID!");
        require(contractors[newContractor] == 0, "This User Is Already A Contractor");
        Subcoop memory subcoop = subcoops[_subcoopId];
        require(subcoop.subcoopId != 0, "Subcoop ID Doesn't Exists!");
        require(subcoop.contractor == address(0), "This Subcoop Already Has A Contractor");
        subcoop.contractor = newContractor;
        contractors[newContractor] += 1;
        subcoops[_subcoopId] = subcoop;
        emit ContractorAdded(_subcoopId, newContractor);
    }

    function addSubcoopMember(uint256 _subcoopId, bool _optin) external {
        require(_subcoopId > 0, "Invalid ID Parameter");
        if (!memberExists[_subcoopId][address(msg.sender)]) {
            memberExists[_subcoopId][address(msg.sender)] = _optin;
            subcoops[_subcoopId].memberCount++;
        } 
    }
 
}