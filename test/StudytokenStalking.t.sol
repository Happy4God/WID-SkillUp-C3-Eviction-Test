
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StudyToken.sol";
import "../src/StudyTokenStaking.sol";

contract StudyTokenStakingTest is Test {
    StudyToken public token;
    StudyTokenStaking public staking;
    
    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 constant STAKING_PERIOD = 30 days;
    uint256 constant REWARD_RATE = 1000; // 10% annual
    
    function setUp() public {
        // Deploy token and staking contract
        token = new StudyToken(INITIAL_SUPPLY);
        staking = new StudyTokenStaking(address(token), STAKING_PERIOD, REWARD_RATE);
        
        // Fund staking contract with rewards
        token.transfer(address(staking), 100000 * 10**18);
    }
    
    function testStakeTokens() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Approve and stake tokens
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        
        // Check total staked amount
        assertEq(staking.totalStaked(), stakeAmount);
        
        // Check user stake info
        (uint256 amount, , , ) = staking.getStakeInfo(address(this));
        assertEq(amount, stakeAmount);
    }
    
    function testCheckBalance() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 balanceBefore = token.balanceOf(address(this));
        
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        
        uint256 balanceAfter = token.balanceOf(address(this));
        
        // Balance should decrease by stake amount
        assertEq(balanceBefore - balanceAfter, stakeAmount);
    }
    
    function testRewardCalculation() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        
        // Initial reward should be zero
        uint256 reward = staking.calculateReward(address(this));
        assertEq(reward, 0);
    }
    
    function testEmergencyWithdraw() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        
        uint256 balanceBefore = token.balanceOf(address(this));
        
        // Emergency withdraw
        staking.emergencyWithdraw();
        
        uint256 balanceAfter = token.balanceOf(address(this));
        
        // Should get back the staked amount
        assertEq(balanceAfter, balanceBefore + stakeAmount);
        
        // Total staked should be zero
        assertEq(staking.totalStaked(), 0);
    }
    
    function testGetStakeInfo() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        token.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        
        (uint256 amount, uint256 startTime, uint256 reward, bool canUnstake) = 
            staking.getStakeInfo(address(this));
        
        assertEq(amount, stakeAmount);
        assertGt(startTime, 0);
        assertEq(reward, 0); // No time passed yet
        assertFalse(canUnstake); // Cannot unstake immediately
    }
}
