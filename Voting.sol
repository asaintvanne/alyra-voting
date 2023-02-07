// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/utils/Strings.sol";

struct Voter {
    bool isRegistered;
    bool hasVoted;
    uint votedProposalId;
}

struct Proposal {
    string description;
    uint voteCount;
}

enum WorkflowStatus {
    RegisteringVoters,
    ProposalsRegistrationStarted,
    ProposalsRegistrationEnded,
    VotingSessionStarted,
    VotingSessionEnded,
    VotesTallied
}

contract Voting is Ownable {

    mapping(address => Voter) private voters;
    Proposal[] private proposals;
    WorkflowStatus private status = WorkflowStatus.RegisteringVoters;

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

    function changeStatus(WorkflowStatus _newStatus) public onlyOwner() {
        int difference = int(uint(_newStatus)) - int(uint(status));
        require(difference == 1, "Change to this status is not allowed from current status");

        WorkflowStatus _oldStatus = status;
        status = _newStatus;
        emit WorkflowStatusChange(_oldStatus, _newStatus);
    }

    function registerVoter(address _address) public onlyOwner() onlyStatus(WorkflowStatus.RegisteringVoters) {
        require(!voters[_address].isRegistered, "Voter is already registered");

        voters[_address] = Voter(true, false, 0);
        emit VoterRegistered(_address);
    }

    function registerProposal(string memory _description) public onlyVoter() onlyStatus(WorkflowStatus.ProposalsRegistrationStarted) {
        for (uint i = 0; i < proposals.length; i++) {
            require(!Strings.equal(_description, proposals[i].description), "Proposal is already registred");
        }

        uint index = proposals.length;
        proposals.push(Proposal(_description, 0));

        emit ProposalRegistered(index);
    }

    function getProposals() public view returns(Proposal[] memory) {
        require(uint(status) >= uint(WorkflowStatus.ProposalsRegistrationStarted), "Proposal registration has not been started");

        return proposals;
    }

    function vote(uint proposalId) public onlyVoter() onlyStatus(WorkflowStatus.VotingSessionStarted) {
        require(proposalId < proposals.length, "Proposal does not exist");
        require(!voters[_msgSender()].hasVoted, "User has already voted");

        proposals[proposalId].voteCount++;
        voters[_msgSender()].hasVoted = true;
        voters[_msgSender()].votedProposalId = proposalId;

        emit Voted(_msgSender(), proposalId);
    }

    function checkVote(address _address) public view onlyVoter() returns(Proposal memory) {
        require(uint(status) >= uint(WorkflowStatus.VotingSessionStarted), "Vote has not started yet");
        require(voters[_address].hasVoted, "Voter has not voted yet");

        return proposals[voters[_address].votedProposalId];
    }

    function getWinner() public view onlyStatus(WorkflowStatus.VotesTallied) returns(Proposal memory) {
        require(proposals.length > 0, "There is no winner because there is no proposal");

        uint winnerId = 0;
        for (uint i = 1; i < proposals.length; i++) {
            if (proposals[i].voteCount > proposals[winnerId].voteCount) {
                winnerId = i;
            }
        }

        return proposals[winnerId];
    }
}
