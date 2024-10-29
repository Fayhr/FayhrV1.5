// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./FayhrGov.sol";
import "./FayhrCrowdfund.sol";

contract Fayhr is FayhrGov {

    // State Variables
    FayhrGov public fayhrGov;
    FayhrCrowdfund public fayhrCrowdfund;
    address public tokenAddress;
    bool public isActive;


    // Events
    event ContractDeactivatedBy(address deactivator);
    event nonFunctionDeposit(address sender, uint256 amount);

    // Modifiers
    modifier onlyWhenActive() {
        require(isActive == true, "contract is inactive");
        _;
    }

    // Constructor
    constructor(address _admin, uint256 _consensusPeriod, address _tokenAddress, address _feecollector) FayhrGov(_admin, _consensusPeriod) {
        fayhrCrowdfund = new FayhrCrowdfund(_tokenAddress, _feecollector);
        tokenAddress = _tokenAddress;
        isActive = true;
    }

    function _proposal(uint256 _subcoopId, uint256 proposeId,  string memory reason, bool verdict) external onlyWhenActive {
        fayhrGov.proposal(_subcoopId, proposeId,  reason, verdict);
    }

    function _veto(uint256 _subcoopId, uint256 proposeId, bool verdict) external onlyWhenActive {
        fayhrGov.veto(_subcoopId, proposeId, verdict);
    }

    function _vetoproposal(uint256 _subcoopId, uint256 proposeId) external onlyWhenActive {
        fayhrGov.vetoproposal(_subcoopId, proposeId);
    }

    function _addContractor(address _contractor, uint256 _subcoopId, string memory _subcoopName) external onlyWhenActive {
        fayhrGov.addContractor(_contractor, _subcoopId, _subcoopName);
    }

    function _removeContractor(address _contractor, uint256 _subcoopId) external onlyWhenActive {
        fayhrGov.RemoveContractor(_contractor, _subcoopId);
    }

    function _addContractorAfterVeto(address newContractor, uint256 _subcoopId) external onlyWhenActive {
        fayhrGov.addContractorAfterVeto(newContractor, _subcoopId);
    }

    function _createpoll(uint256 _subcoopId, uint256 crowdfundId, string memory _name, uint256 _requiredYesVotes, bool verdict, bool verdict2) external onlyContractors onlySubcoopAuth(_subcoopId) onlyWhenActive {
        fayhrCrowdfund.createPoll(_subcoopId, crowdfundId, _name, _requiredYesVotes, verdict, verdict2);
    }

    function _vote(uint256 crowdfundId, bool choice) external onlyWhenActive {
        fayhrCrowdfund.vote(crowdfundId, choice);
    }

    function _deleteCrowdfundAndPoll(uint256 crowdfundId, uint256 _subcoopId) external onlyContractors onlySubcoopAuth(_subcoopId) onlyWhenActive {
        fayhrCrowdfund.deleteCrowdfundAndPoll(crowdfundId);
    }

    function _startCrowdfund(uint256 crowdfundId,
        uint256 _subcoopId,
        uint256 _productCost,
        uint256 _deliveryDividend,
        uint256 _agencyFee,
        uint256 _slotHard,
        uint256 _slotSoft,
        uint256 _startTime,
        uint256 _endTime,
        bool verdict
        ) external onlyContractors onlySubcoopAuth(_subcoopId) onlyWhenActive {
        fayhrCrowdfund.startCrowdfund(crowdfundId, _subcoopId, _productCost, _deliveryDividend, _agencyFee, _slotHard, _slotSoft, _startTime, _endTime, verdict);
    }

    function _delegateToken(uint256 _subcoopId, uint256 crowdfundId, uint256 _slotUnit, bool _optin) external onlyWhenActive {
        fayhrGov.addSubcoopMember(_subcoopId, _optin); // optin must be true
        fayhrCrowdfund.delegateToken(_subcoopId, crowdfundId, _slotUnit);
    }

    function _claimToken(uint256 _subcoopId, uint256 crowdfundId) external onlyWhenActive {
        fayhrCrowdfund.claimToken(_subcoopId, crowdfundId);
    }

    function _cancelCrowdfund(uint256 _subcoopId, uint256 crowdfundId, bool verdict) external onlyContractors onlySubcoopAuth(_subcoopId) onlyWhenActive {
        fayhrCrowdfund.cancelCrowdfund(crowdfundId, verdict);
    }

    function _restartCanceledCrowdfund(
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
        ) external onlyContractors onlySubcoopAuth(_subcoopId) onlyWhenActive {
        fayhrCrowdfund.restartCanceledCrowdfund(crowdfundId, _subcoopId, _productCost, _deliveryDividend, _agencyFee, _slotHard, _slotSoft, _startTime, _endTime, verdict);
    }

    function _withdrawDivAndProduct(uint256 _subcoopId, uint256 crowdfundId) external onlyContractors onlySubcoopAuth(_subcoopId) onlyWhenActive {
        fayhrCrowdfund.withdrawDivAndProduct(_subcoopId, crowdfundId);
    }

    function _permitFeeWithdrawal(uint256 _subcoopId, uint256 crowdfundId, bool verdict) external onlyAdmin onlyWhenActive {
        fayhrCrowdfund.permitFeeWithdrawal(_subcoopId, crowdfundId, verdict);
    }

    function _withdrawContractorFee(uint256 _subcoopId, uint256 crowdfundId) external onlyContractors onlySubcoopAuth(_subcoopId) onlyWhenActive {
        fayhrCrowdfund.withdrawContractorFee(_subcoopId, crowdfundId);
    }

    function deleteContract(address payable _admin, bool verdict) external onlyAdmin onlyWhenActive {
        IERC20 token = IERC20(tokenAddress);
        isActive = verdict; // Verdict Must Be False 
        token.transfer(address(msg.sender), token.balanceOf(address(this)));
        _admin.transfer(address(this).balance);
        emit ContractDeactivatedBy(msg.sender);
    }

    receive() external payable {
        emit nonFunctionDeposit(msg.sender, msg.value);
    }

}