// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IVotePool.sol";

contract VotePool is IVotePool {

    uint public override totalVote;

    constructor() public {}

    function changeVote(uint _vote) external {
        totalVote = _vote;
    }

}
