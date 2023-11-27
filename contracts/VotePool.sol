// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
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

    mapping(address => VoterInfo) public voters;

    // events
    event ChangeManager(address indexed manager);
    event SubmitPercentChange(uint indexed percent);
    event ConfirmPercentChange(uint indexed percent);
    event AddMargin(address indexed sender, uint amount);
    event ChangeState(State indexed state);
    event Exit(address indexed validator);
    event WithdrawMargin(address indexed recipient, uint amount);
    event Punish(address indexed validator, uint amount);
    event RemoveIncoming(address indexed validator, uint amount);
    event ExitVote(address indexed sender, uint amount);
    event WithdrawValidatorReward(address indexed recipient, uint amount);
    event WithdrawVoteReward(address indexed recipient, uint amount);
    event Deposit(address indexed sender, uint amount);
    event Withdraw(address indexed recipient, uint amount);

    struct PercentChange {
        uint newPercent;
        uint submitBlk;
    }

    struct VoterInfo {
        uint amount;
        uint rewardDebt;
        uint withdrawPendingAmount;
        uint withdrawExitBlock;
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

    function changeManager(address _manager) external onlyManager {
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

    function isIdleStateLike() public view returns (bool) {
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
            punishContract.cleanPunishRecord(validator);
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

    function withdrawValidatorReward()
        external
        payable
        nonReentrant
        onlyManager
    {
        validatorsContract.withdrawReward();
        require(validatorReward > 0, "No more reward");

        uint _amount = validatorReward;
        validatorReward = 0;
        sendValue(msg.sender, _amount);
        emit WithdrawValidatorReward(msg.sender, _amount);
    }

    function getValidatorPendingReward() external view returns (uint) {
        uint _poolPendingReward = validatorsContract.pendingReward(
            IVotePool(address(this))
        );
        uint _rewardForValidator = _poolPendingReward.mul(percent).div(
            PERCENT_BASE
        );

        return validatorReward.add(_rewardForValidator);
    }

    function getPendingReward(address _voter) external view returns (uint) {
        uint _poolPendingReward = validatorsContract.pendingReward(
            IVotePool(address(this))
        );
        uint _rewardForValidator = _poolPendingReward.mul(percent).div(
            PERCENT_BASE
        );

        uint _share = accRewardPerShare;
        if (totalVote > 0) {
            _share = _poolPendingReward
                .sub(_rewardForValidator)
                .mul(COEFFICIENT)
                .div(totalVote)
                .add(_share);
        }

        return
            _share.mul(voters[_voter].amount).div(COEFFICIENT).sub(
                voters[_voter].rewardDebt
            );
    }

    function deposit() external payable nonReentrant {
        validatorsContract.withdrawReward();

        uint _pendingReward = accRewardPerShare
            .mul(voters[msg.sender].amount)
            .div(COEFFICIENT)
            .sub(voters[msg.sender].rewardDebt);

        if (msg.value > 0) {
            voters[msg.sender].amount = voters[msg.sender].amount.add(
                msg.value
            );
            voters[msg.sender].rewardDebt = voters[msg.sender]
                .amount
                .mul(accRewardPerShare)
                .div(COEFFICIENT);
            totalVote = totalVote.add(msg.value);
            emit Deposit(msg.sender, msg.value);

            if (state == State.Ready) {
                validatorsContract.improveRanking();
            }
        } else {
            voters[msg.sender].rewardDebt = voters[msg.sender]
                .amount
                .mul(accRewardPerShare)
                .div(COEFFICIENT);
        }

        if (_pendingReward > 0) {
            sendValue(msg.sender, _pendingReward);
            emit WithdrawVoteReward(msg.sender, _pendingReward);
        }
    }

    function exitVote(uint _amount) external nonReentrant {
        require(_amount > 0, "Value should not be zero");
        require(_amount <= voters[msg.sender].amount, "Insufficient amount");

        validatorsContract.withdrawReward();

        uint _pendingReward = accRewardPerShare
            .mul(voters[msg.sender].amount)
            .div(COEFFICIENT)
            .sub(voters[msg.sender].rewardDebt);

        totalVote = totalVote.sub(_amount);

        voters[msg.sender].amount = voters[msg.sender].amount.sub(_amount);
        voters[msg.sender].rewardDebt = voters[msg.sender]
            .amount
            .mul(accRewardPerShare)
            .div(COEFFICIENT);

        if (state == State.Ready) {
            validatorsContract.lowerRanking();
        }

        voters[msg.sender].withdrawPendingAmount = voters[msg.sender]
            .withdrawPendingAmount
            .add(_amount);
        voters[msg.sender].withdrawExitBlock = block.number;

        sendValue(msg.sender, _pendingReward);

        emit ExitVote(msg.sender, _amount);
        emit WithdrawVoteReward(msg.sender, _pendingReward);
    }

    function withdraw() external nonReentrant {
        require(
            block.number.sub(voters[msg.sender].withdrawExitBlock) >
                WithdrawLockPeriod,
            "token not released"
        );
        require(
            voters[msg.sender].withdrawPendingAmount > 0,
            "no vote token to be withdrawed"
        );

        uint _amount = voters[msg.sender].withdrawPendingAmount;
        voters[msg.sender].withdrawPendingAmount = 0;
        voters[msg.sender].withdrawExitBlock = 0;

        sendValue(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function withdrawVoterReward() external nonReentrant {
        require(voters[msg.sender].amount > 0, "no vote no reward");
        validatorsContract.withdrawReward();

        uint _accRewards = accRewardPerShare.mul(voters[msg.sender].amount).div(COEFFICIENT);
        uint _pendingRewards = _accRewards.sub(voters[msg.sender].rewardDebt);
        // update debt
        voters[msg.sender].rewardDebt = _accRewards;

        require(_pendingRewards > 0, "no rewards");
        sendValue(msg.sender, _pendingRewards);
        emit WithdrawVoteReward(msg.sender, _pendingRewards);
    }

    function punish() external override onlyPunishContract {
        punishBlk = block.number;

        if (state != State.Pause) {
            state = State.Jail;
            emit ChangeState(state);
        }
        validatorsContract.removeRanking();

        uint _punishAmount = margin >= PunishAmount ? PunishAmount : margin;
        if (_punishAmount > 0) {
            margin = margin.sub(_punishAmount);
            sendValue(address(0), _punishAmount);
            emit Punish(validator, _punishAmount);
        }

        return;
    }

    function removeValidatorIncoming() external override onlyPunishContract {
        validatorsContract.withdrawReward();

        uint _incoming = validatorReward < PunishAmount
            ? validatorReward
            : PunishAmount;

        validatorReward = validatorReward.sub(_incoming);
        if (_incoming > 0) {
            sendValue(address(0), _incoming);
            emit RemoveIncoming(validator, _incoming);
        }
    }
}
