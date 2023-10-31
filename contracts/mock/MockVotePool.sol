// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IVotePool.sol";

contract VotePool is IVotePool {
    uint public override totalVote;
    ValidatorType public override validatorType;
    State public override state;
    address public override validator;

    constructor() public {}

    function changeVote(uint _vote) external {
        totalVote = _vote;
    }

    function switchState(bool pause) external override {}
}
