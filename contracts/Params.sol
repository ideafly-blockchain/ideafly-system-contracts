// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./interfaces/IValidators.sol";
import "./interfaces/IPunish.sol";

contract Params {
    bool public initialized;

    // System contracts
    IValidators public constant validatorsContract =
        IValidators(0x000000000000000000000000000000000000d001);
    IPunish public constant punishContract =
        IPunish(0x000000000000000000000000000000000000D002);

    // System params

    // max active validators 
    uint16 public constant MaxValidators = 21;
    // margin threshold for a PoS type of validator
    uint public constant PosMinMargin = 5000 ether;
    // margin threshold for a PoA type of validator
    uint public constant PoaMinMargin = 1 ether;

    // The punish amount from validators margin when the validator is jailed
    uint public constant PunishAmount = 100 ether;

    // JailPeriod: a block count, how many blocks a validator should be jailed when it got punished
    uint public constant JailPeriod = 86400;
    // when a validator claim to exit, how many blocks its margin should be lock 
    // (after that locking period, the valicator can withdraw its margin)
    uint public constant MarginLockPeriod = 403200;
    // when a voter claim to withdraw its stake(vote), how many blocks its token should be lock
    uint public constant WithdrawLockPeriod = 86400;
    // when a validator change its commison rate, it should take `PercentChangeLockPeriod` blocks to take effect
    uint public constant PercentChangeLockPeriod = 86400;
    uint constant PERCENT_BASE = 10000;

    modifier onlyMiner() {
        require(msg.sender == block.coinbase, "Miner only");
        _;
    }

    modifier onlyNotInitialized() {
        require(!initialized, "Already initialized");
        _;
    }

    modifier onlyInitialized() {
        require(initialized, "Not init yet");
        _;
    }

    modifier onlyValidatorsContract() {
        require(
            msg.sender == address(validatorsContract),
            "Validators contract only"
        );
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier onlyBlockEpoch(uint256 epoch) {
        require(block.number % epoch == 0, "Block epoch only");
        _;
    }

    modifier onlyPunishContract() {
        require(msg.sender == address(punishContract), "Punish contract only");
        _;
    }
}
