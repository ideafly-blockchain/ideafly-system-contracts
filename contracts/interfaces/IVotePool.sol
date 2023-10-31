// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

interface IVotePool {
    // return the state of current validator
    function state() external view returns (State);

    // return the ValidatorType of current validator
    function validatorType() external view returns (ValidatorType);

    // return the current validator's total vote
    function totalVote() external view returns (uint);

    // return the validator address that current VotePool contract represents
    function validator() external view returns (address);

    function switchState(bool pause) external;

    function punish() external;

    function removeValidatorIncoming() external;
}

enum ValidatorType {
    Pos,
    Poa
}

// enum of validator state
enum State {
    Idle,
    Ready,
    Pause,
    Jail
}
