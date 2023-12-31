// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MatchVesting is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Constants *************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant TGE = 100;

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Variables *************************************** //
    // ---------------------------------------------------------------------------------------- //

    address public matchToken;

    struct VestingInfo {
        uint256 start;
        uint256 cliff; // If have lock period, cliff = start + lock period
        uint256 duration; // Duration starts from "start time" (not "cliff time")
        uint256 interval;
        uint256 amount; // Total amount
        uint256 tgeAmount; // Amount released at TGE
        uint256 vestedAmount; // Already vested
        uint256 vestedPerTime; // Vested amount each time
    }
    mapping(address user => VestingInfo vestingInfo) public vestings;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event NewVestingSet(
        address receiver,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        uint256 interval,
        uint256 amount,
        uint256 tgeAmount
    );
    event VestingStopped(address investor);
    event Withdraw(address investor, uint256 amount);

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Initializer ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function initialize(address _matchToken) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        matchToken = _matchToken;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    // ! If a receiver's vesting is "all released at tge"
    // ! Should set it with parameters:
    // !  -> start = cliff 
    // !  -> duration = 0 & inteval = 0
    // !  -> amount = tgeAmount
    function setNewVesting(
        address _receiver,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _interval,
        uint256 _amount,
        uint256 _tgeAmount
    ) public onlyOwner {
        require(_amount > 0, "Amount must be greater than zero");
        require(_amount >= _tgeAmount, "Amount must be greater than tge");
        require(_start >= TGE, "Should start at or after TGE");
        require(_start <= _cliff, "Cliff must be after start");
        require(_start + _duration >= block.timestamp, "Vesting must end in the future");

        // Store the new vesting info
        VestingInfo storage newVesting = vestings[_receiver];
        newVesting.start = _start;
        newVesting.cliff = _cliff;
        newVesting.duration = _duration;
        newVesting.interval = _interval;
        newVesting.amount = _amount;
        newVesting.tgeAmount = _tgeAmount;

        // Total times of distribution
        if (_interval > 0) {
            uint256 totalTimes = ((_duration - (_cliff - _start)) / _interval) + 1;
            newVesting.vestedPerTime = (_amount - _tgeAmount) / totalTimes;
        }

        emit NewVestingSet(_receiver, _start, _cliff, _duration, _interval, _amount, _tgeAmount);
    }

    function setNewVestings(VestingInfo[] memory _vestings, address[] memory _receivers) external onlyOwner {
        for (uint256 i; i < _vestings.length; ) {
            setNewVesting(
                _receivers[i],
                _vestings[i].start,
                _vestings[i].cliff,
                _vestings[i].duration,
                _vestings[i].interval,
                _vestings[i].amount,
                _vestings[i].tgeAmount
            );
            unchecked {
                ++i;
            }
        }
    }

    // Stop a user's vesting
    // When updating vesting info, stop it and set a new one
    function stopVesting(address _receiver) external onlyOwner {
        require(vestings[_receiver].amount > 0, "Not an active investor");

        delete vestings[_receiver];
        emit VestingStopped(_receiver);
    }

    function claim() external nonReentrant {
        VestingInfo memory userVesting = vestings[msg.sender];

        require(userVesting.start > 0, "You have no vesting");
        require(block.timestamp >= userVesting.start, "Start has not passed");
        require(userVesting.amount - userVesting.vestedAmount > 0, "All claimed");

        uint256 amountToWithdraw = vestedAmount(msg.sender) - userVesting.vestedAmount;
        require(amountToWithdraw > 0, "No tokens to withdraw now");

        uint256 amountTransferred = _safeMatchTransfer(msg.sender, amountToWithdraw);
        require(amountTransferred > 0, "Not enough balance in contract");

        vestings[msg.sender].vestedAmount += amountTransferred;

        emit Withdraw(msg.sender, amountTransferred);
    }

    function vestedAmount(address _user) public view returns (uint256) {
        VestingInfo memory userVesting = vestings[_user];

        // Before start, no tokens
        if (block.timestamp < userVesting.start) {
            return 0;
        }
        // Start => Cliff, tokens = TGERelease
        else if (block.timestamp < userVesting.cliff) {
            return userVesting.tgeAmount;
        }
        // After end, all vested
        else if (block.timestamp >= userVesting.start + userVesting.duration) {
            return userVesting.amount;
        }
        // Cliff => End, tokens = TGE + interval * times
        else {
            uint256 timePassed = block.timestamp - userVesting.cliff;
            uint256 distributeTimes = (timePassed / userVesting.interval) + 1;

            return userVesting.tgeAmount + (userVesting.vestedPerTime * distributeTimes);
        }
    }

    function _safeMatchTransfer(address _to, uint256 _amount) internal returns (uint256) {
        uint256 balance = IERC20(matchToken).balanceOf(address(this));

        if (_amount > balance) {
            IERC20(matchToken).safeTransfer(_to, balance);
            return balance;
        } else {
            IERC20(matchToken).safeTransfer(_to, _amount);
            return _amount;
        }
    }
}
