// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Params.sol";
import "./library/SafeMath.sol";
import "./interfaces/IVotePool.sol";
import "./interfaces/IValidators.sol";
import "./library/ReentrancyGuard.sol";
import "./library/SafeSend.sol";

contract VotePool is Params, ReentrancyGuard, SafeSend, IVotePool {
    using SafeMath for uint;
    uint constant COEFFICIENT = 1e18;

    ValidatorType public override validatorType;
    State public override state;
    address public override validator;
    uint public override totalVote;

    address public manager;

    uint public margin;

    //comission rate in percent, base on `PERCENT_BASE` defined in Params
    uint public percent;

    PercentChange public pendingPercentChange;
    //the block number on which current validator was punished
    uint public punishBlk;
    // the block number on which current validator announce to exit
    uint public exitBlk;

    //reward for validator not for voters
    uint validatorReward;
    //use to calc voter's reward
    uint accRewardPerShare;

    // events
    event ChangeManager(address indexed manager);
    event SubmitPercentChange(uint indexed percent);
    event ConfirmPercentChange(uint indexed percent);
    event AddMargin(address indexed sender, uint amount);
    event ChangeState(State indexed state);
    event Exit(address indexed validator);
    event WithdrawMargin(address indexed sender, uint amount);

    struct PercentChange {
        uint newPercent;
        uint submitBlk;
    }

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

    constructor(
        address _validator,
        address _manager,
        uint _percent,
        ValidatorType _type,
        State _state
    )
        public
        onlyValidatorsContract
        onlyValidAddress(_validator)
        onlyValidAddress(_manager)
        onlyValidPercent(_type, _percent)
    {
        validator = _validator;
        manager = _manager;
        percent = _percent;
        validatorType = _type;
        state = _state;
    }

    // only for the first time to init poa validators
    function initialize() external onlyValidatorsContract onlyNotInitialized {
        initialized = true;
        validatorsContract.improveRanking();
    }

    function changeManager(address _manager) external onlyValidator {
        manager = _manager;
        emit ChangeManager(_manager);
    }

    //base on 1000
    function submitPercentChange(
        uint _percent
    ) external onlyManager onlyValidPercent(validatorType, _percent) {
        pendingPercentChange.newPercent = _percent;
        pendingPercentChange.submitBlk = block.number;

        emit SubmitPercentChange(_percent);
    }

    function confirmPercentChange()
        external
        onlyManager
        onlyValidPercent(validatorType, pendingPercentChange.newPercent)
    {
        require(
            pendingPercentChange.submitBlk > 0 &&
                block.number.sub(pendingPercentChange.submitBlk) >
                PercentChangeLockPeriod,
            "Interval not long enough"
        );

        percent = pendingPercentChange.newPercent;
        pendingPercentChange.newPercent = 0;
        pendingPercentChange.submitBlk = 0;

        emit ConfirmPercentChange(percent);
    }

    function isIdleStateLike() internal view returns (bool) {
        return
            state == State.Idle ||
            (state == State.Jail && block.number.sub(punishBlk) > JailPeriod);
    }

    function addMargin() external payable onlyManager {
        require(isIdleStateLike(), "Incorrect state");
        require(
            exitBlk == 0 || block.number.sub(exitBlk) > MarginLockPeriod,
            "Interval not long enough"
        );
        require(msg.value > 0, "Value should not be zero");

        exitBlk = 0;
        margin = margin.add(msg.value);

        emit AddMargin(msg.sender, msg.value);

        uint minMargin;
        if (validatorType == ValidatorType.Poa) {
            minMargin = PoaMinMargin;
        } else {
            minMargin = PosMinMargin;
        }

        if (margin >= minMargin) {
            state = State.Ready;
            validatorsContract.improveRanking();

            emit ChangeState(state);
        }
    }

    function exit() external onlyManager {
        require(state == State.Ready || isIdleStateLike(), "Incorrect state");
        exitBlk = block.number;

        if (state != State.Idle) {
            state = State.Idle;
            emit ChangeState(state);

            validatorsContract.removeRanking();
        }
        emit Exit(validator);
    }

    function withdrawMargin() external nonReentrant onlyManager {
        require(isIdleStateLike(), "Incorrect state");
        require(
            exitBlk > 0 && block.number.sub(exitBlk) > MarginLockPeriod,
            "Interval not long enough"
        );
        require(margin > 0, "No more margin");

        exitBlk = 0;

        uint _amount = margin;
        margin = 0;
        sendValue(msg.sender, _amount);
        emit WithdrawMargin(msg.sender, _amount);
    }

    function switchState(bool pause) external override onlyValidatorsContract {
        if (pause) {
            require(
                isIdleStateLike() || state == State.Ready,
                "Incorrect state"
            );

            state = State.Pause;
            emit ChangeState(state);
            validatorsContract.removeRanking();
            return;
        } else {
            require(state == State.Pause, "Incorrect state");

            state = State.Idle;
            emit ChangeState(state);
            return;
        }
    }

    function receiveReward() external payable onlyValidatorsContract {
        uint _rewardForValidator = msg.value.mul(percent).div(PERCENT_BASE);
        validatorReward = validatorReward.add(_rewardForValidator);

        if (totalVote > 0) {
            accRewardPerShare = msg
                .value
                .sub(_rewardForValidator)
                .mul(COEFFICIENT)
                .div(totalVote)
                .add(accRewardPerShare);
        }
    }
}
