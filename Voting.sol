// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Strings.sol";

contract Voting is Ownable {

    WorkflowStatus public status = WorkflowStatus.RegisteringVoters; //Everyone can check the status
    mapping(address => Voter) private voters;
    Proposal[] private proposals;
    uint private winningProposalId;

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    modifier onlyStatus(WorkflowStatus _status) {
        require(status == _status, "This operation is not allowed when the vote is in its current status");
        _;
    }

    modifier onlyVoter() {
        require(voters[_msgSender()].isRegistered, "User is not registered on voters");
        _;
    }

    function incrementStatus() external onlyOwner() {
        require(status != WorkflowStatus.VotesTallied, "Status cannot be incremented because vote is tallied");

        WorkflowStatus _oldStatus = status;
        status = Voting.WorkflowStatus(uint(status) + 1);

        if (status == WorkflowStatus.VotesTallied) {
            _declareWinner();
        }

        emit WorkflowStatusChange(_oldStatus, status);
    }


    function registerVoter(address _address) external onlyOwner() onlyStatus(WorkflowStatus.RegisteringVoters) {
        require(!voters[_address].isRegistered, "Voter is already registered");

        voters[_address] = Voter(true, false, 0);
        emit VoterRegistered(_address);
    }

    function registerProposal(string memory _description) external onlyStatus(WorkflowStatus.ProposalsRegistrationStarted) onlyVoter() {
        for (uint i = 0; i < proposals.length; i++) {
            require(!Strings.equal(_description, proposals[i].description), "Proposal is already registred");
        }

        uint index = proposals.length;
        proposals.push(Proposal(_description, 0));

        emit ProposalRegistered(index);
    }

    function getProposals() external view returns(string[] memory) {
        require(uint(status) >= uint(WorkflowStatus.ProposalsRegistrationStarted), "Proposal registration has not been started");

        string[] memory props = new string[](proposals.length);
        for(uint i = 0; i < proposals.length; i++) {
            props[i] = proposals[i].description;
        }

        return props;
    }

    function vote(uint _proposalId) external onlyStatus(WorkflowStatus.VotingSessionStarted) onlyVoter() {
        require(_proposalId < proposals.length, "Proposal does not exist");
        require(!voters[_msgSender()].hasVoted, "User has already voted");

        proposals[_proposalId].voteCount++;
        voters[_msgSender()].hasVoted = true;
        voters[_msgSender()].votedProposalId = _proposalId;

        emit Voted(_msgSender(), _proposalId);
    }

    function checkVote(address _address) external view onlyVoter() returns(Proposal memory) {
        require(uint(status) >= uint(WorkflowStatus.VotingSessionStarted), "Vote has not started yet");
        require(voters[_address].hasVoted, "Voter has not voted yet");

        return proposals[voters[_address].votedProposalId];
    }

    function _declareWinner() private onlyOwner onlyStatus(WorkflowStatus.VotesTallied) {
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

    function getWinner() external view onlyStatus(WorkflowStatus.VotesTallied) returns(string memory) {
        require(proposals.length > 0, "There is no winner because there is no proposal");

        return proposals[winningProposalId].description;
    }
}
