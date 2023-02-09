// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "./ERC20Token.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Strings.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/math/Math.sol";

/**
 * Vote contract 
 */
contract InvestmentVoting is Ownable {

    WorkflowStatus public status = WorkflowStatus.RegisteringVoters; //Everyone can check the status
    mapping(address => Voter) private voters;
    Proposal[] private proposals;
    uint private winningProposalId;

    address[] private contributors;
    TokenParams private tokenParams;
    ERC20Token private token;

    /**
     * Status declared in workflow order
     */
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied,
        CollectingStarted,
        CollectingEnded,
        Closed
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
        uint contribution;
    }

    struct Proposal {
        string description;
        uint amount;
        uint voteCount;
        uint contributed;
    }

    struct TokenParams {
        string name;
        string symbol;
    }

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event Contributed(address, uint amount);

    constructor() payable {
        require(msg.value == 1 ether, "Contract must be deployed with 1 ether");
    }

    /**
     * Check if status in argument is equal to current vote status. 
     */
    modifier onlyStatus(WorkflowStatus _status) {
        require(status == _status, "This operation is not allowed when the vote is in current status");
        _;
    }

    /**
     * Check if status in argument is equal or superior to current vote status. 
     */
    modifier onlyStatusAtLess(WorkflowStatus _status) {
        require(status >= _status, "This operation is not allowed when the vote is in current status");
        _;
    }

    /**
     * Check if sender is a registred voter 
     */
    modifier onlyVoter() {
        require(voters[_msgSender()].isRegistered, "User is not registered on voters");
        _;
    }

    /**
     * Change status to the next one 
     */
    function incrementStatus() external onlyOwner() {
        require(status != WorkflowStatus.Closed, "Status cannot be incremented because vote is closed");

        WorkflowStatus _oldStatus = status;
        status = InvestmentVoting.WorkflowStatus(uint(status) + 1);

        if (status == WorkflowStatus.VotesTallied) {
            _declareWinner();
        } else if (status == WorkflowStatus.Closed) {
            _close();
        }

        emit WorkflowStatusChange(_oldStatus, status);
    }


    function registerVoter(address _address) external onlyOwner() onlyStatus(WorkflowStatus.RegisteringVoters) {
        require(!voters[_address].isRegistered, "Voter is already registered");

        voters[_address] = Voter(true, false, 0, 0);
        emit VoterRegistered(_address);
    }

    function registerProposal(string memory _description, uint _amount) external onlyStatus(WorkflowStatus.ProposalsRegistrationStarted) onlyVoter() {
        require(!Strings.equal(_description, ""), "Proposal cannot be empty");
        require(_amount > 0, "Proposal cannot be empty");
        for (uint i = 0; i < proposals.length; i++) {
            require(!Strings.equal(_description, proposals[i].description), "Proposal is already registred");
        }

        uint index = proposals.length;
        proposals.push(Proposal(_description, _amount, 0, 0));

        emit ProposalRegistered(index);
    }

    function getProposals() external view onlyStatusAtLess(WorkflowStatus.ProposalsRegistrationStarted) returns(string[] memory) {
        string[] memory props = new string[](proposals.length);
        for(uint i = 0; i < proposals.length; i++) {
            props[i] = proposals[i].description;
        }

        return props;
    }

    function vote(uint _proposalId) external onlyVoter() onlyStatus(WorkflowStatus.VotingSessionStarted) {
        require(_proposalId < proposals.length, "Proposal does not exist");
        require(!voters[_msgSender()].hasVoted, "User has already voted");

        proposals[_proposalId].voteCount++;
        voters[_msgSender()].hasVoted = true;
        voters[_msgSender()].votedProposalId = _proposalId;

        emit Voted(_msgSender(), _proposalId);
    }

    /**
     * Voters can contribute to invest in proposal
     * If contributor reaches proposal amount, surplus is refund
     * If amount is reached, any can contribute again
     */
    function contribute() external payable onlyVoter() onlyStatus(WorkflowStatus.CollectingStarted) {
        require(proposals.length > 0, "Contribution is not allowed because there is no winning proposal");
        require(msg.value > 0 wei, "Contribution should not be equal to 0");
        require(proposals[winningProposalId].contributed < proposals[winningProposalId].amount, "Contribution amount is reached");

        uint realContribution = Math.min(msg.value, proposals[winningProposalId].amount - proposals[winningProposalId].contributed);
        voters[_msgSender()].contribution += realContribution;
        proposals[winningProposalId].contributed += realContribution;
        contributors.push(_msgSender());
        _sendMoneyTo(_msgSender(), msg.value - realContribution, true);

        if (realContribution > 0) {
            emit Contributed(_msgSender(), realContribution);
        }
    }

    function checkVote(address _address) external view onlyVoter() onlyStatusAtLess(WorkflowStatus.VotingSessionStarted) returns(string memory) {
        require(voters[_address].hasVoted, "Voter has not voted");

        return proposals[voters[_address].votedProposalId].description;
    }

    /**
     * Retrieve the winning proposal Id. If many proposals receives the same number of votes,
     * winning proposal is randomly declared.
     * If there is no proposal, winningProposalId stays at 0
     * Be careful that function remains called once over the life of the contract bacause random
     * choice may change between runs
     */
    function _declareWinner() private onlyOwner() onlyStatus(WorkflowStatus.VotesTallied) {
        if (proposals.length > 0) {

            //Get number of proposal with highest vote count
            uint winnerVoteCount = 0;
            uint nbWinners = 0;
            for (uint i = 0; i < proposals.length; i++) {
                if (proposals[i].voteCount > winnerVoteCount) {
                    winnerVoteCount = proposals[i].voteCount;
                    nbWinners = 1;
                } else if (proposals[i].voteCount == winnerVoteCount) {
                    nbWinners++;
                }
            }

            // Get proposals with highest vote count
            uint[] memory winnerIndexes = new uint[](nbWinners);
            uint index = 0;
            for (uint i = 0; i < proposals.length; i++) {
                if (proposals[i].voteCount == winnerVoteCount) {
                    winnerIndexes[index] = i;
                    index++;
                }
            }

            // Random winner if necessary
            if (nbWinners == 1) {
                winningProposalId = winnerIndexes[0];
            } else {
                winningProposalId = winnerIndexes[uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, winnerIndexes))) % nbWinners];
            }

        }
    }

    /**
     * Retrieve the winner from winningProposalId
     * If there is no proposal, winningProposalId stayed at 0 but proposal 0 is not winner
     */
    function getWinner() external view onlyStatusAtLess(WorkflowStatus.VotesTallied) returns(string memory) {
        require(proposals.length > 0, "There is no winner because there is no proposal");

        return proposals[winningProposalId].description;
    }

    function _close() private onlyOwner() onlyStatus(WorkflowStatus.Closed) {
        if (proposals.length > 0) {
            if (proposals[winningProposalId].contributed == proposals[winningProposalId].amount) {
                require(!Strings.equal(tokenParams.name, ""), "Token params are not set");
                //Give one 1 token for 1 wei to contributors
                token = new ERC20Token(tokenParams.name, tokenParams.symbol);
                for (uint i = 0; i < contributors.length; i++) {
                    token.mint(contributors[i], voters[contributors[i]].contribution);
                }
            } else {
                assert(address(this).balance >= proposals[winningProposalId].contributed);
                //Refund contributors if proposal amount is not reached
                for (uint i = 0; i < contributors.length; i++) {
                    _sendMoneyTo(contributors[i], voters[contributors[i]].contribution, false);
                }
                
            }            
        }

        //Refund owner with unused money
        _sendMoneyTo(_msgSender(), address(this).balance, false);
    }

    function setTokenParams(string calldata _name, string calldata _symbol) external onlyOwner() onlyStatus(WorkflowStatus.CollectingEnded) {
        require(!Strings.equal(_name, ""), "Token name cannot be empty");
        require(!Strings.equal(_symbol, ""), "Token symbol cannot be empty");

        tokenParams = TokenParams(_name, _symbol);
    }

    function _sendMoneyTo(address _address, uint _amount, bool checkBalance) private {
        if (checkBalance) {
            assert(address(this).balance >= _amount);
        }
        (bool success, )= _address.call{value: _amount}("");
        require(success, "Transfert failed");
    }
}
