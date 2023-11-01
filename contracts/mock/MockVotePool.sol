// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "../Params.sol";
// #else
import "./MockParams.sol";
// #endif
import "../interfaces/IVotePool.sol";
import "../interfaces/IValidators.sol";

contract VotePool is Params, IVotePool {
    uint public override totalVote;
    ValidatorType public override validatorType;
    State public override state;
    address public override validator;

    IValidators pool;
    address public manager;
    uint public percent;

    constructor(
        address _miner,
        address _manager,
        uint _percent,
        ValidatorType _type,
        State _state
    ) public {
        pool = IValidators(msg.sender);
        validator = _miner;
        manager = _manager;
        percent = _percent;
        validatorType = _type;
        state = _state;
    }

    function initialize() external {
        initialized = true;
        validatorsContract.improveRanking();
    }

    function changeVote(uint _vote) external {
        totalVote = _vote;
    }

    function changeVoteAndRanking(IValidators validators, uint _vote) external {
        if (_vote > totalVote) {
            totalVote = _vote;
            validators.improveRanking();
        } else {
            totalVote = _vote;
            validators.lowerRanking();
        }
    }

    function changeState(State _state) external {
        state = _state;
    }

    function switchState(bool pause) external override {}

    function punish() external override {}

    function removeValidatorIncoming() external override {}

    function receiveReward() external payable {}
}
