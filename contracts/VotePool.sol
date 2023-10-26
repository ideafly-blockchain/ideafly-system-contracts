// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Params.sol";
import "./library/SafeMath.sol";
import "./interfaces/IVotePool.sol";
import "./interfaces/IValidators.sol";

contract VotePool is Params, IVotePool {
    using SafeMath for uint;

    ValidatorType public override validatorType;
    State public override state;
    address public override validator;
    uint public override totalVote;

    address public manager;

    uint public margin;

    //comission rate in percent, base on `PERCENT_BASE` defined in Params
    uint public percent;

    modifier onlyValidator() {
        require(msg.sender == validator, "Only validator allowed");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager allowed");
        _;
    }

    modifier onlyValidPercent(ValidatorType _type, uint _percent) {
        //zero represents null value, trade as invalid
        if (_type == ValidatorType.Poa) {
            require(_percent <= PERCENT_BASE, "Invalid percent");
        } else {
            // currently its a hard cap for pos-validator's commission rate (30%);
            require(_percent <= PERCENT_BASE.mul(3).div(10), "Invalid percent");
        }
        _;
    }

    constructor(address _validator, address _manager, uint _percent, ValidatorType _type, State _state)
    public
    onlyValidatorsContract
    onlyValidAddress(_validator)
    onlyValidAddress(_manager)
    onlyValidPercent(_type, _percent) {
        validator = _validator;
        manager = _manager;
        percent = _percent;
        validatorType = _type;
        state = _state;
    }

    // only for the first time to init poa validators
    function initialize()
    external
    onlyValidatorsContract
    onlyNotInitialized {
        initialized = true;
        validatorsContract.improveRanking();
    }

}
