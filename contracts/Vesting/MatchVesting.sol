// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MatchKOLVesting is OwnableUpgradeable, ReentrancyGuardUpgradeable {
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
        uint256 cliff;
        uint256 duration;
        uint256 interval;
        uint256 amount;
        uint256 tgeAmount;
        uint256 vestedAmount;
        uint256 vestedPerTime;
    }
    mapping(address kol => VestingInfo vestingInfo) public vestings;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event NewVestingSet(
        address investor,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        uint256 interval,
        uint256 totalAmount,
        uint256 TGERelease
    );
    event StopVesting(address investor);
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

    function setNewVesting(
        address _kol,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _interval,
        uint256 _totalAmount,
        uint256 _tgeAmount
    ) public onlyOwner {
        require(_totalAmount > 0, "Amount must be greater than zero");
        require(_start >= TGE, "Should start at or after TGE");
        require(_start <= _cliff, "Cliff must be after start");
        require(_start + _duration >= block.timestamp, "Vesting must end in the future");

        VestingInfo storage newVesting = vestings[_kol];

        newVesting.start = _start;
        newVesting.cliff = _cliff;
        newVesting.duration = _duration;
        newVesting.interval = _interval;
        newVesting.amount = _totalAmount;
        newVesting.tgeAmount = _tgeAmount;

        // Total times of distribution
        uint256 totalTimes = ((_duration - (_cliff - _start)) / _interval) + 1;
        newVesting.vestedPerTime = (_totalAmount - _tgeAmount) / totalTimes;

        emit NewVestingSet(_kol, _start, _cliff, _duration, _interval, _totalAmount, _tgeAmount);
    }

    function setNewVestings(VestingInfo[] memory _vestings, address[] memory _kols) external onlyOwner {
        for (uint256 i; i < _vestings.length; ) {
            setNewVesting(
                _kols[i],
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

    function stopVesting(address _kol) external onlyOwner {
        require(vestings[_kol].amount > 0, "Not an active investor");

        delete vestings[_kol];
        emit StopVesting(_kol);
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
