// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract  {
    using SafeERC20 for IERC20;

    IERC20 public wethToken;
    IERC20 public myToken;

    uint public annualizedAPR = 14;  // 14% APR
    uint public compoundingFeePercentage = 1; // 1% fee for auto-compounding


    // Mapping to tract staked balances
    mapping(address => uint) public stakedBalances;
    mapping(address => bool) public autoCompundingOptIns; // Tract users who opted in for auto-compunding
    mapping(address => uint) public userLastCompoundingTime;
    // Events for tracking staking and auto-compounding
    event Staked(address indexed user, uint256 amount);
    event Compounded(address indexed user, uint256 amount);
    event OptedInAutoCompounding(address indexed user);
    event AutoCompoundingTriggered(address indexed triggerer, uint256 totalFees);

    constructor(address _wethToken, address _myToken) {
     wethToken = IERC20(_wethToken);
     myToken = IERC20(_myToken);
    }

     // Function to stake ETH and receive receipt tokens
    function stakeETH() external payable {
        require(msg.value > 0, "Must stake ETH");
        uint256 stakingAmount = msg.value;
        uint256 receiptTokensToMint = calculateTokensToMint(stakingAmount);
        stakedBalances[msg.sender] += stakingAmount;
        myToken.transfer(msg.sender, receiptTokensToMint);
        emit Staked(msg.sender, stakingAmount);
    }

     // Function to calculate tokens to mint based on staking amount and APR
    function calculateTokensToMint(uint256 stakingAmount) internal view returns (uint256) {
        // Calculate tokens based on APR and convert to an annual rate
        uint256 annualRate = (stakingAmount * annualizedAPR) / 100;
        // Divide by 365 to get daily rate and multiply by 3650 for 10 years
        uint256 tokensToMint = (annualRate * 3650) / 365;
        return tokensToMint;
    }

     // Function to opt-in for auto-compounding
    function optInAutoCompounding() external {
        require(!autoCompundingOptIns[msg.sender], "Already opted in");
        autoCompundingOptIns[msg.sender] = true;
        emit OptedInAutoCompounding(msg.sender);
    }



    function withdraw() external {
    uint256 stakedAmount = stakedBalances[msg.sender];
    require(stakedAmount > 0, "No staked balance");

    // Calculate the number of earned tokens
    uint256 earnedTokens = calculateTokensToMint(stakedAmount);

    // Ensure the contract has enough tokens to fulfill the withdrawal
    require(myToken.balanceOf(address(this)) >= earnedTokens, "Insufficient contract balance");

    // Transfer earned tokens to the user
    myToken.safeTransfer(msg.sender, earnedTokens);

    // Reset user's staked balance to zero
    stakedBalances[msg.sender] = 0;

    // Transfer staked ETH back to the user
    payable(msg.sender).transfer(stakedAmount);

    emit Compounded(msg.sender, earnedTokens);
}

function withdrawRewards() external {
    require(autoCompundingOptIns[msg.sender], "Not opted-in for auto-compounding");

    uint256 rewards = calculateRewards(msg.sender);
    uint256 fees = (rewards * compoundingFeePercentage) / 100;
    uint256 netRewards = rewards - fees;

    // Transfer the net rewards to the user
    myToken.safeTransfer(msg.sender, netRewards);

    emit Compounded(msg.sender, netRewards);
}

function calculateRewards(address user) internal view returns (uint256) {
    require(autoCompundingOptIns[user], "Not opted in for auto-compounding");

   
    uint256 stakedBalance = stakedBalances[user];
    uint256 annualReward = (stakedBalance * annualizedAPR) / 100;
    
   
    uint256 lastCompoundingTime = getLastCompoundingTime(user);
    uint256 timeSinceLastCompounding = block.timestamp - lastCompoundingTime;
    uint256 annualizedReward = (annualReward * timeSinceLastCompounding) / 31536000; // 31536000 seconds in a year
    
    return annualizedReward;
}


            

function getLastCompoundingTime(address _user) internal view returns (uint256) {
     return userLastCompoundingTime[_user];
}


}