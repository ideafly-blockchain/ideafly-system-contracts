// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Params.sol";
import "./library/SafeMath.sol";
import "./VotePool.sol";
import "./library/SortedList.sol";
import "./interfaces/IVotePool.sol";
import "./interfaces/IValidators.sol";

contract Validators is Params, IValidators {
    using SafeMath for uint;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    mapping(ValidatorType => uint8) public count;
    mapping(ValidatorType => uint8) public backupCount;

    address[] public allValidators;
    mapping(address => IVotePool) public votePools;

    mapping(ValidatorType => SortedLinkedList.List) topVotePools;

    event AddValidator(address indexed validator, address votePool);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegistered() {
        IVotePool _pool = IVotePool(msg.sender);
        require(votePools[_pool.validator()] == _pool, "Vote pool not registered");
        _;
    }

    /**
    * @dev for the NPoS engine to initialize this system contract
    */
    function initialize(address[] memory _validators, address[] memory _managers, address _admin)
    external
    onlyNotInitialized {
        require(_validators.length > 0 && _validators.length == _managers.length, "Invalid params");
        require(_admin != address(0), "Invalid admin address");

        initialized = true;
        admin = _admin;

        count[ValidatorType.Pos] = 0;
        count[ValidatorType.Poa] = 21;
        backupCount[ValidatorType.Pos] = 0;
        backupCount[ValidatorType.Poa] = 0;

        for (uint8 i = 0; i < _validators.length; i++) {
            address _validator = _validators[i];
            require(votePools[_validator] == IVotePool(0), "Validators already exists");
            VotePool _pool = new VotePool(_validator, _managers[i], PERCENT_BASE, ValidatorType.Poa, State.Ready);
            allValidators.push(_validator);
            votePools[_validator] = _pool;

            _pool.initialize();
        }
    }

    /**
    * @dev register new validator
    */
    function addValidator(address _validator, address _manager, uint _percent, ValidatorType _type)
    external
    onlyAdmin
    returns (address) {
        require(votePools[_validator] == IVotePool(0), "Validators already exists");

        VotePool _pool = new VotePool(_validator, _manager, _percent, _type, State.Idle);

        allValidators.push(_validator);
        votePools[_validator] = _pool;

        emit AddValidator(_validator, address(_pool));

        return address(_pool);
    }

    /**
    * @dev for the VotePool to improve its own ranking
    */
    function improveRanking()
    external
    override
    onlyRegistered {
        IVotePool _pool = IVotePool(msg.sender);
        require(_pool.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools[_pool.validatorType()];
        _list.improveRanking(_pool);
    }

    /**
    * @dev for the VotePool to lower its own ranking
    */
    function lowerRanking()
    external
    override
    onlyRegistered {
        IVotePool _pool = IVotePool(msg.sender);
        require(_pool.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools[_pool.validatorType()];
        _list.lowerRanking(_pool);
    }

    /**
    * @dev for the VotePool to remove itself when it was punished
    */
    function removeRanking()
    external
    override
    onlyRegistered {
        IVotePool _pool = IVotePool(msg.sender);

        SortedLinkedList.List storage _list = topVotePools[_pool.validatorType()];
        _list.removeRanking(_pool);
    }

}
