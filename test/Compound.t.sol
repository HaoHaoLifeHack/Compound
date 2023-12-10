// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../script/Deploy.s.sol";

contract CompoundTest is Test, Deploy {
    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address otherUser = makeAddr("otherUser");
    address liquidator = makeAddr("liquidator");
    uint256 initialAmount = 100 ether;

    function setUp() public {
        vm.startPrank(admin);
        _deploy(admin);
        vm.stopPrank();
        deal(address(tokenA), user1, initialAmount);
        deal(address(tokenB), user1, initialAmount);
        deal(address(tokenA), otherUser, initialAmount);
        deal(address(tokenB), otherUser, initialAmount);
        deal(address(tokenA), liquidator, initialAmount);
        deal(address(tokenB), liquidator, initialAmount);
    }

    function testMintAndRedeem() public {
        vm.startPrank(user1);
        tokenA.approve(address(cTokenA), tokenA.balanceOf(user1));
        cTokenA.mint(100 ether);
        assertEq(tokenA.balanceOf(user1), initialAmount - 100 ether);
        assertEq(cTokenA.balanceOf(user1), 100 ether);

        cTokenA.redeem(100 ether);
        assertEq(tokenA.balanceOf(user1), initialAmount);
        assertEq(cTokenA.balanceOf(user1), 0);

        vm.stopPrank();
    }

    function testBorrowAndRepay() public {
        _makeInitialLiquidity();
        _borrow();
        vm.startPrank(user1);
        tokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.repayBorrow(50 ether);
        assertEq(tokenA.balanceOf(user1), initialAmount);
        vm.stopPrank();
        // vm.startPrank(user1);
        // tokenB.approve(address(cTokenB), cTokenB.balanceOf(user1));
        // cTokenB.mint(1 ether);
        // assertEq(cTokenB.balanceOf(user1), 1 ether);
        // //check user1 has enough collateral
        // uint256 user1CollateralValue = cTokenB.balanceOf(user1) / 2;
        // console2.log(user1CollateralValue);
        // address[] memory cToken = new address[](1);

        // cToken[0] = address(cTokenB);
        // comptroller.enterMarkets(cToken);
        // console2.log(cTokenA.getCash());

        // cTokenA.borrow(50 ether);
        // assertEq(tokenA.balanceOf(user1), initialAmount + 50 ether);

        // vm.stopPrank();
    }

    function testBorrowAndLiquidate1() public {
        _makeInitialLiquidity();
        _borrow();
        // decrease cTokenB's Collateral factor (50% => 10%)
        vm.prank(admin);
        Comptroller(address(unitroller))._setCollateralFactor(
            CToken(address(cTokenB)),
            1e17
        );

        // liquidate User1 by liquidator
        vm.startPrank(liquidator);
        tokenA.approve(address(cTokenA), type(uint256).max);

        // check User1 whether he is qualified for liquidation
        (, , uint256 shortfall) = Comptroller(address(unitroller))
            .getAccountLiquidity(user1);
        require(shortfall > 0, "no shortfall");
        uint256 borrowAmount = cTokenA.borrowBalanceStored(user1);

        // liquidating is limited by Close Factor => 50%
        cTokenA.liquidateBorrow(user1, borrowAmount / 2, cTokenB);
        assertEq(
            tokenA.balanceOf(liquidator),
            initialAmount - borrowAmount / 2
        );
        // calculate the seize tokens that liquidator gets
        (, uint256 seizeTokens) = Comptroller(address(unitroller))
            .liquidateCalculateSeizeTokens(
                address(cTokenA),
                address(cTokenB),
                borrowAmount / 2
            );
        // liquidator gets the seize tokens, minus the protocolSeizeShareMantissa
        assertEq(
            cTokenB.balanceOf(liquidator),
            (seizeTokens * (1e18 - cTokenA.protocolSeizeShareMantissa())) / 1e18
        );
        vm.stopPrank();
    }

    function testBorrowAndLiquidate2() public {
        _makeInitialLiquidity();
        _borrow();

        // decrease cTokenB' price (100USD => 50USD)
        vm.prank(admin);
        priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 5e19);

        // liquidate User1 by liquidator
        vm.startPrank(liquidator);
        tokenA.approve(address(cTokenA), tokenA.balanceOf(liquidator));

        // check User1 whether he is qualified for liquidation
        (, , uint256 shortfall) = Comptroller(address(unitroller))
            .getAccountLiquidity(user1);
        require(shortfall > 0, "no shortfall");
        uint256 borrowBalance = cTokenA.borrowBalanceStored(user1);
        // liquidating is limited by Close Factor => 50%
        cTokenA.liquidateBorrow(user1, borrowBalance / 2, cTokenB);
        assertEq(
            tokenA.balanceOf(liquidator),
            initialAmount - borrowBalance / 2
        );
        // calculate the seize tokens that liquidator gets
        (, uint256 seizeTokens) = Comptroller(address(unitroller))
            .liquidateCalculateSeizeTokens(
                address(cTokenA),
                address(cTokenB),
                borrowBalance / 2
            );
        //
        assertEq(
            cTokenB.balanceOf(liquidator),
            (seizeTokens * (1e18 - cTokenA.protocolSeizeShareMantissa())) / 1e18
        );
        vm.stopPrank();
    }

    function _makeInitialLiquidity() private {
        // Add liquidity for tokenA's pool by otherUser
        vm.startPrank(otherUser);
        tokenA.approve(address(cTokenA), tokenA.balanceOf(otherUser));
        cTokenA.mint(100 ether);
        vm.stopPrank();
    }

    function _borrow() private {
        // Add liquidity for tokenB's pool by user1
        vm.startPrank(user1);
        tokenB.approve(address(cTokenB), tokenB.balanceOf(user1));
        cTokenB.mint(1 ether);
        assertEq(cTokenB.balanceOf(user1), 1 ether);

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        Comptroller(address(unitroller)).enterMarkets(cTokens);

        cTokenA.borrow(50 ether);
        assertEq(tokenA.balanceOf(user1), initialAmount + 50 ether);
        vm.stopPrank();
    }
}
