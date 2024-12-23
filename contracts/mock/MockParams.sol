// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
import "../interfaces/IValidators.sol";
import "../interfaces/IPunish.sol";


contract Params {
    bool public initialized;

    // System contracts
    IValidators
        public validatorsContract;
    IPunish
        public punishContract;

    // System params
    uint8 public constant MaxValidators = 21;

    uint public constant PosMinMargin = 5 ether;
    uint public constant PoaMinMargin = 1 ether;

    uint public constant PunishAmount = 1 ether;

    uint constant PERCENT_BASE = 10000;

    uint public constant JailPeriod = 0;
    uint public constant MarginLockPeriod = 0;
    uint public constant WithdrawLockPeriod = 0;
    uint public constant PercentChangeLockPeriod = 0;

    modifier onlyEngine() {
        // require(msg.sender == engineCaller, "Engine only");
        _;
    }

    modifier onlyNotInitialized() {
        // require(!initialized, "Already initialized");
        _;
    }

    modifier onlyInitialized() {
        // require(initialized, "Not init yet");
        _;
    }

    modifier onlyValidatorsContract() {
        // require(
            // msg.sender == address(validatorsContract),
            // "Validators contract only"
        // );
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier onlyBlockEpoch(uint256 epoch) {
        // require(block.number % epoch == 0, "Block epoch only");
        _;
    }

    modifier onlyPunishContract() {
        // require(msg.sender == address(punishContract), "Punish contract only");
        _;
    }

    function setAddress(address _val, address _punish)
    external {
        validatorsContract = IValidators(_val);
        punishContract = IPunish(_punish);
    }
}
