// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FayhrCrowdfund is ReentrancyGuard {
    
    // State Variables
    address public tokenAddress;
    address private feecollector;
    uint256 public nextCrowdfundId;
    
    // Enums
    enum Authorization {
        inactive,
        active,
        cancel
    }

    enum Withdrawals {
        none,
        productdiv,
        agencyfee
    }

    // Structs
    struct CrowdfundType {
        uint256 id;
        string name;
        uint256 requiredYesVotes;
        uint256 availableYesVotes;
        uint256 slot;
        uint256 startTime;
        uint256 endTime;
        uint256 softCap;
        uint256 hardCap;
        uint256 totalContributed;
        uint256 contributionCount;
        Authorization authorization;
        bool closed;
        bool pollClosed;
    }

    struct SlotCalculation {
        uint256 productCost;
        uint256 agencyFee;
        uint256 deliveryDividend;
        uint256 slotHard;
        uint256 slotSoft;
        uint256 slot;
        Withdrawals withdrawals;
        bool feeAllowance;
    }

    // Mappings
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => CrowdfundType) public crowdfundTypes;
    mapping(uint256 => mapping(uint256 => bool)) public SubcoopCrowdfunds;
    mapping(uint256 => bool) public withdrawalAllowance;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public contributions;
    mapping(uint256 => mapping(uint256 => SlotCalculation)) public slotcalculations;

    // Events
    event PollCreated(uint256 id, string name);
    event CrowdfundAndPollDeleted(uint256 id);
    event CrowdfundStarted(
        uint256 id, uint256 slot, uint256 startTime, uint256 endTime, uint256 softCap, uint256 hardCap
    );
    event CrowdfundCreated(
        uint256 id, uint256 slot, uint256 startTime, uint256 endTime, uint256 softCap, uint256 hardCap
    );
    event TokenDelegated(uint256 id, uint256 amount, uint256 slotUnit);
    event TokenClaimed(uint256 id, uint256 amount);
    event CrowdfundCanceled(uint256 id);
    event CrowdfundWithdrawn(uint256 id, uint256 amount);
    event VotePlaced(address voter, bool vote);
    event FeePermissionGranted(uint256 Id, uint256 id);
    event FeeWithdrawn(uint256 Id, uint256 id);

    // Constructor
    constructor(address _tokenAddress, address _feecollector) {
        tokenAddress = _tokenAddress;
        feecollector = _feecollector;
    }

    // Functions
    function createPoll(uint256 _subcoopId, uint256 crowdfundId, string memory _name, uint256 _requiredYesVotes, bool verdict, bool verdict2)
        external
    {
        require(crowdfundId > 0 && _subcoopId > 0, "Invalid Crowdfund ID!");
        require(crowdfundTypes[crowdfundId].id == 0, "Crowdfund ID already exists!");
        uint256 newCrowdfundId;
        if (nextCrowdfundId == 0) {
            nextCrowdfundId++;
            newCrowdfundId = nextCrowdfundId;
            nextCrowdfundId++;
        } else if (crowdfundId > 0) {
            newCrowdfundId = nextCrowdfundId;
            nextCrowdfundId++;
        }
        // Verdict must be False & Verdict2 must be true
        CrowdfundType storage newCrowdfundType = crowdfundTypes[newCrowdfundId];
        newCrowdfundType.id = newCrowdfundId;
        newCrowdfundType.name = _name;
        newCrowdfundType.requiredYesVotes = _requiredYesVotes;
        newCrowdfundType.availableYesVotes = 0;
        newCrowdfundType.slot = 0;
        newCrowdfundType.startTime = 0;
        newCrowdfundType.endTime = 0;
        newCrowdfundType.softCap = 0;
        newCrowdfundType.hardCap = 0;
        newCrowdfundType.totalContributed = 0;
        newCrowdfundType.authorization = Authorization.inactive;
        newCrowdfundType.closed = verdict;
        newCrowdfundType.pollClosed = verdict;
        SubcoopCrowdfunds[_subcoopId][newCrowdfundId] = verdict2;
        emit PollCreated(newCrowdfundId, _name);
    }

    function vote(uint256 crowdfundId, bool choice) external {
        require(crowdfundTypes[crowdfundId].pollClosed != true, "Poll Closed");
        require(crowdfundTypes[crowdfundId].id != 0, "Crowdfund Doesn't Exist!");
        require(!hasVoted[crowdfundId][msg.sender], "Already Voted");
        hasVoted[crowdfundId][msg.sender] = true;
        if (choice && crowdfundTypes[crowdfundId].availableYesVotes < crowdfundTypes[crowdfundId].requiredYesVotes) {
            crowdfundTypes[crowdfundId].availableYesVotes++;
            emit VotePlaced(msg.sender, choice);
        }
        else if (choice && crowdfundTypes[crowdfundId].availableYesVotes == crowdfundTypes[crowdfundId].requiredYesVotes) {
            crowdfundTypes[crowdfundId].authorization = Authorization.active;
            crowdfundTypes[crowdfundId].closed = choice;
            crowdfundTypes[crowdfundId].pollClosed = choice; // choice must be true
            emit CrowdfundCreated(
                crowdfundId,
                crowdfundTypes[crowdfundId].slot,
                crowdfundTypes[crowdfundId].startTime,
                crowdfundTypes[crowdfundId].endTime,
                crowdfundTypes[crowdfundId].softCap,
                crowdfundTypes[crowdfundId].hardCap
            );
        } 
        else {
            emit VotePlaced(msg.sender, choice);
        }
    }

    function deleteCrowdfundAndPoll(uint256 crowdfundId) external {
        require(crowdfundTypes[crowdfundId].id != 0, "Poll/Crowdfund Doesn't Exist");
        delete crowdfundTypes[crowdfundId];
        emit CrowdfundAndPollDeleted(crowdfundId);
    }

    function startCrowdfund(
        uint256 crowdfundId,
        uint256 _subcoopId,
        uint256 _productCost,
        uint256 _deliveryDividend,
        uint256 _agencyFee,
        uint256 _slotHard,
        uint256 _slotSoft,
        uint256 _startTime,
        uint256 _endTime,
        bool verdict
    ) external {
        require(crowdfundTypes[crowdfundId].id != 0, "Crowdfund Doesn't Exist");
        require(_endTime > _startTime, "Endtime not > Starttime");
        require(crowdfundTypes[crowdfundId].authorization == Authorization.active, "Crowdfund Not Activated");
        uint256 _slot = computeSlotPrice(_productCost, _agencyFee, _deliveryDividend);
        crowdfundTypes[crowdfundId].slot = _slot;
        uint256 _softCap = _slot * _slotSoft;
        uint256 _hardCap = _slot * _slotHard;
        crowdfundTypes[crowdfundId].startTime = block.timestamp + _startTime;
        crowdfundTypes[crowdfundId].endTime = block.timestamp + _endTime;
        crowdfundTypes[crowdfundId].softCap = _softCap;
        crowdfundTypes[crowdfundId].hardCap = _hardCap;
        crowdfundTypes[crowdfundId].totalContributed = 0;
        crowdfundTypes[crowdfundId].closed = verdict; // verdict must be false
        SlotCalculation storage newSlotCalculation = slotcalculations[_subcoopId][crowdfundId];
        newSlotCalculation.productCost = _productCost;
        newSlotCalculation.deliveryDividend = _deliveryDividend;
        newSlotCalculation.agencyFee = _agencyFee;
        newSlotCalculation.slotHard = _slotHard;
        newSlotCalculation.slotSoft = _slotSoft;
        newSlotCalculation.slot = _slot;
        newSlotCalculation.withdrawals = Withdrawals.none;
        newSlotCalculation.feeAllowance = verdict;
        emit CrowdfundStarted(crowdfundId, _slot, _startTime, _endTime, _softCap, _hardCap);
    }

    function delegateToken(uint256 _subcoopId, uint256 crowdfundId, uint256 _slotUnit) external {
        IERC20 token = IERC20(tokenAddress);
        require(_subcoopId > 0 && crowdfundId > 0, "Invalid ID Parameters");
        require(SubcoopCrowdfunds[_subcoopId][crowdfundId] == true && crowdfundTypes[crowdfundId].id != 0, "Subcoop And CrowdfundId Doesn't Exist");
        require(
            crowdfundTypes[crowdfundId].authorization == Authorization.active && !crowdfundTypes[crowdfundId].closed,
            "Crowdfund not Active / Closed"
        );
        require(
            block.timestamp > crowdfundTypes[crowdfundId].startTime
                && block.timestamp < crowdfundTypes[crowdfundId].endTime,
            "Delegation Time Ended"
        );
        uint256 delegateAmount = crowdfundTypes[crowdfundId].slot * _slotUnit;
        require(delegateAmount % crowdfundTypes[crowdfundId].slot == 0, "Inappropriate Slot Unit");
        require(token.allowance(msg.sender, address(this)) >= delegateAmount, "Insufficient Allowance");
        require(token.balanceOf(msg.sender) >= delegateAmount, "Insufficient Token Balance");
        token.transferFrom(address(msg.sender), address(this), delegateAmount);
        crowdfundTypes[crowdfundId].totalContributed += delegateAmount;
        crowdfundTypes[crowdfundId].contributionCount += _slotUnit;
        contributions[_subcoopId][crowdfundId][msg.sender] += delegateAmount;
        if (crowdfundTypes[crowdfundId].totalContributed == crowdfundTypes[crowdfundId].hardCap) {
            bool verdict = true;
            crowdfundTypes[crowdfundId].closed = verdict;
        } else if (
            crowdfundTypes[crowdfundId].totalContributed > crowdfundTypes[crowdfundId].softCap
                && block.timestamp > crowdfundTypes[crowdfundId].endTime
        ) {
            bool verdict = true;
            crowdfundTypes[crowdfundId].closed = verdict;
        }
        emit TokenDelegated(crowdfundId, delegateAmount, _slotUnit);
    }

    function claimToken(uint256 _subcoopId, uint256 crowdfundId) external nonReentrant {
        IERC20 token = IERC20(tokenAddress);
        require(_subcoopId > 0 && crowdfundId > 0, "Invalid ID Parameters");
        require(SubcoopCrowdfunds[_subcoopId][crowdfundId] == true && crowdfundTypes[crowdfundId].id != 0, "Subcoop And CrowdfundId Doesn't Exist");
        if (
            crowdfundTypes[crowdfundId].totalContributed <= crowdfundTypes[crowdfundId].softCap
                && block.timestamp > crowdfundTypes[crowdfundId].endTime
        ) {
            bool verdict = true;
            crowdfundTypes[crowdfundId].closed = verdict;
        }
        require(crowdfundTypes[crowdfundId].closed, "Crowdfund Is Not Closed");
        require(
            crowdfundTypes[crowdfundId].totalContributed < crowdfundTypes[crowdfundId].softCap
                || crowdfundTypes[crowdfundId].authorization == Authorization.cancel,
            "Softcap Reached / Crowdfund Not Canceled"
        );
        uint256 claimAmount = contributions[_subcoopId][crowdfundId][msg.sender];
        require(claimAmount != 0, "No Funds Available");
        contributions[_subcoopId][crowdfundId][msg.sender] = 0;
        crowdfundTypes[crowdfundId].totalContributed -= claimAmount;
        token.transfer(address(msg.sender), claimAmount);
        emit TokenClaimed(crowdfundId, claimAmount);
    }

    function cancelCrowdfund(uint256 crowdfundId, bool verdict) external {
        crowdfundTypes[crowdfundId].closed = verdict;
        crowdfundTypes[crowdfundId].authorization = Authorization.cancel;
        emit CrowdfundCanceled(crowdfundId);
    }

    function restartCanceledCrowdfund(
        uint256 crowdfundId,
        uint256 _subcoopId,
        uint256 _productCost,
        uint256 _deliveryDividend,
        uint256 _agencyFee,
        uint256 _slotHard,
        uint256 _slotSoft,
        uint256 _startTime,
        uint256 _endTime,
        bool verdict
    ) external {
        require(crowdfundTypes[crowdfundId].id != 0, "Crowdfund Doesn't Exist");
        require(crowdfundTypes[crowdfundId].totalContributed == 0, "Funds Not Claimed, Wait or Create New Entry");
        require(_endTime > _startTime, "Endtime not > Starttime");
        uint256 _slot = computeSlotPrice(_productCost, _agencyFee, _deliveryDividend);
        uint256 _softCap = _slot * _slotSoft;
        uint256 _hardCap = _slot * _slotHard;
        crowdfundTypes[crowdfundId].authorization = Authorization.active;
        crowdfundTypes[crowdfundId].slot = _slot;
        crowdfundTypes[crowdfundId].startTime = block.timestamp + _startTime;
        crowdfundTypes[crowdfundId].endTime = block.timestamp + _endTime;
        crowdfundTypes[crowdfundId].softCap = _softCap;
        crowdfundTypes[crowdfundId].hardCap = _hardCap;
        crowdfundTypes[crowdfundId].closed = verdict; // verdict should be false
        crowdfundTypes[crowdfundId].contributionCount = 0;
        slotcalculations[_subcoopId][crowdfundId].productCost = _productCost;
        slotcalculations[_subcoopId][crowdfundId].deliveryDividend = _deliveryDividend;
        slotcalculations[_subcoopId][crowdfundId].agencyFee = _agencyFee;
        slotcalculations[_subcoopId][crowdfundId].slotHard = _slotHard;
        slotcalculations[_subcoopId][crowdfundId].slotSoft = _slotSoft;
        slotcalculations[_subcoopId][crowdfundId].slot = _slot;
        slotcalculations[_subcoopId][crowdfundId].feeAllowance = verdict;
        emit CrowdfundStarted(crowdfundId, _slot, _startTime, _endTime, _softCap, _hardCap);
    }

    function withdrawDivAndProduct(uint256 _subcoopId, uint256 crowdfundId) external nonReentrant {
       IERC20 token = IERC20(tokenAddress);
       require(crowdfundTypes[crowdfundId].closed, "Crowdfund Not Closed");
       require(crowdfundTypes[crowdfundId].authorization == Authorization.active, "Crowdfund Already Canceled");
       require(
            crowdfundTypes[crowdfundId].totalContributed > crowdfundTypes[crowdfundId].softCap
                || crowdfundTypes[crowdfundId].totalContributed == crowdfundTypes[crowdfundId].hardCap,
            "Delegate Caps Not Reached"
        );
        require(slotcalculations[_subcoopId][crowdfundId].withdrawals != Withdrawals.productdiv || slotcalculations[_subcoopId][crowdfundId].withdrawals != Withdrawals.agencyfee, "You Have Already Executed This Function");
        uint256 product = slotcalculations[_subcoopId][crowdfundId].productCost;
        uint256 dividend = slotcalculations[_subcoopId][crowdfundId].deliveryDividend;
        uint256 DivandProduct = product + dividend;
        uint256 count = crowdfundTypes[crowdfundId].contributionCount;
        uint256 withdrawalAmount = DivandProduct * count;
        slotcalculations[_subcoopId][crowdfundId].withdrawals = Withdrawals.productdiv;
        token.transfer(address(msg.sender), withdrawalAmount);
        emit CrowdfundWithdrawn(crowdfundId, withdrawalAmount); 
    }

    function permitFeeWithdrawal(uint256 _subcoopId, uint256 crowdfundId, bool verdict) external {
       require(crowdfundTypes[crowdfundId].closed, "Crowdfund Not Closed");
       require(crowdfundTypes[crowdfundId].authorization == Authorization.active, "Crowdfund Already Canceled");
       require(
            crowdfundTypes[crowdfundId].totalContributed > crowdfundTypes[crowdfundId].softCap
                || crowdfundTypes[crowdfundId].totalContributed == crowdfundTypes[crowdfundId].hardCap,
            "Delegate Caps Not Reached"
        );
        require(slotcalculations[_subcoopId][crowdfundId].feeAllowance == false, "You Already Approved This");
        slotcalculations[_subcoopId][crowdfundId].feeAllowance = verdict; // Verdict Must be true;
        emit FeePermissionGranted(_subcoopId, crowdfundId);
    }

    function withdrawContractorFee(uint256 _subcoopId, uint256 crowdfundId) external nonReentrant {
       IERC20 token = IERC20(tokenAddress);
       require(crowdfundTypes[crowdfundId].closed, "Crowdfund Not Closed");
       require(crowdfundTypes[crowdfundId].authorization == Authorization.active, "Crowdfund Already Canceled");
       require(
            crowdfundTypes[crowdfundId].totalContributed > crowdfundTypes[crowdfundId].softCap
                || crowdfundTypes[crowdfundId].totalContributed == crowdfundTypes[crowdfundId].hardCap,
            "Delegate Caps Not Reached"
        );
        require(slotcalculations[_subcoopId][crowdfundId].feeAllowance == true, "Approval Not Granted");
        require(slotcalculations[_subcoopId][crowdfundId].withdrawals != Withdrawals.agencyfee, "You Have Already Executed This Function");
        uint256 fees = slotcalculations[_subcoopId][crowdfundId].agencyFee;
        uint256 count = crowdfundTypes[crowdfundId].contributionCount;
        uint256 feeAmount = fees * count;
        uint256 Amount = feeAmount / 2;
        slotcalculations[_subcoopId][crowdfundId].withdrawals = Withdrawals.agencyfee;
        crowdfundTypes[crowdfundId].contributionCount = 0;
        crowdfundTypes[crowdfundId].totalContributed = 0;
        token.transfer(feecollector, Amount);
        token.transfer(address(msg.sender), Amount);
        emit FeeWithdrawn(_subcoopId, crowdfundId);
    }

    function computeSlotPrice(uint256 _productCost, uint256 _agencyFee, uint256 _deliveryDividend) public pure returns (uint256) {
        uint256 slotprice = _productCost + _deliveryDividend + _agencyFee;
        return (slotprice);
    }

    // Getter Functions
    function getCrowdfund(uint256 crowdfundId) public view returns (CrowdfundType memory) {
        return crowdfundTypes[crowdfundId];
    }

    function getContribution(uint256 _subcoopId, uint256 crowdfundId, address contributor) public view returns (uint256) {
        return contributions[_subcoopId][crowdfundId][contributor];
    }

    function hasUserVoted(uint256 crowdfundId, address user) public view returns (bool) {
        return hasVoted[crowdfundId][user];
    }

}