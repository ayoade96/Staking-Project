// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Dambaz.sol";
import "./DambazWETH.sol";
import "./interface/IDAMBAZ.sol";
import {console2} from "forge-std/Test.sol";

contract Staking {
    

    address WETH_Contract_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IDAMBAZ public weth;

    Dambaz public dambazToken;
    DambazWETH public Wdambaz;

    uint256 public annualInterestRate = 14; // 14% annual interest rate
    uint256 public compoundingFeePercentage = 1; // 1% compounding fee

    struct Stake {
        uint256 stakedAmount;
        uint256 lastStakeTime;
        uint256 totalRewards;
        bool optedForCompounding;
    }

    mapping(address => Stake) public stakers;

    // EVENTS
    event Staked(address indexed user, uint256 amount);
    event Compounded(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // ERRORS
    error NoStakeValue();
    error NoStakedETH();
    error NoRewardToCompound();
    error NoStakedWETH();

    constructor(address _dambazToken, address _dambazWETHToken) {
        weth = IDAMBAZ(weth);
        dambazToken = Dambaz(_dambazToken);
        Wdambaz = DambazWETH(_dambazWETHToken);
    }

    function stakeETH() external payable {
        uint256 ethAmount = msg.value;
        if (ethAmount <= 0) revert NoStakeValue();

        // Convert ETH TO WETH
        weth.deposit{value: ethAmount}();
        console2.logUint(msg.value);

        // Mint "Dambaz-WETH" tokens to the user
        Wdambaz.mint(msg.sender, ethAmount * 10); // 1 ETH = 10 Dambaz tokens

        // Update staker's information
        Stake storage staker = stakers[msg.sender];
        staker.stakedAmount = staker.stakedAmount + ethAmount;
        staker.lastStakeTime = block.timestamp;

        emit Staked(msg.sender, ethAmount);
    }

    function compoundRewards() external {
        Stake storage staker = stakers[msg.sender];

        if (staker.stakedAmount <= 0) revert NoStakedWETH();
        // require(staker.stakedAmount > 0, "No staked WETH");

        uint256 rewardsToCompound = calculateRewardsToCompound(msg.sender);

        if (rewardsToCompound <= 0) revert NoRewardToCompound();

        uint256 fee = (rewardsToCompound * compoundingFeePercentage) / 100;

        // Mint additional Dambaz tokens for the compounding fee
        dambazToken.mint(msg.sender, fee);

        // Convert rewards to WETH
        uint256 wethToStake = (rewardsToCompound - fee) / 10; // 1 ETH = 10 Dambaz tokens

        // Stake the converted WETH as principal
        staker.stakedAmount = staker.stakedAmount + wethToStake;

        // Update staker's total rewards and last stake time
        staker.totalRewards = (staker.totalRewards + rewardsToCompound) - fee;
        staker.lastStakeTime = block.timestamp;

        emit Compounded(msg.sender, rewardsToCompound - fee);
    }

    function withdraw() external {
        Stake storage staker = stakers[msg.sender];

        if (staker.stakedAmount <= 0) revert NoStakedWETH();

        uint256 rewardsToWithdraw = staker.totalRewards;

        require(rewardsToWithdraw > 0, "No rewards to withdraw");

        // Transfer staked WETH and rewards to the user
        weth.transfer(msg.sender, staker.stakedAmount);
        dambazToken.burn(msg.sender, rewardsToWithdraw);

        // Reset staker's information
        staker.stakedAmount = 0;
        staker.totalRewards = 0;
        staker.lastStakeTime = 0;

        emit Withdrawn(msg.sender, staker.stakedAmount - rewardsToWithdraw);
    }

    function setAnnualInterestRate(uint256 _rate) external {
        annualInterestRate = _rate;
    }

    function setCompoundingFeePercentage(uint256 _feePercentage) external {
        require(_feePercentage <= 100, "Fee percentage exceeds 100%");
        compoundingFeePercentage = _feePercentage;
    }

    function calculateRewardsToCompound(
        address stakerAddress
    ) internal view returns (uint256) {
        Stake storage staker = stakers[stakerAddress];
        uint256 timeSinceLastStake = block.timestamp - staker.lastStakeTime;
        uint256 annualSeconds = 365 days;
        uint256 annualRate = (annualInterestRate * annualSeconds) / 100;
        return
            (staker.stakedAmount * annualRate * timeSinceLastStake) /
            annualSeconds;
    }
}