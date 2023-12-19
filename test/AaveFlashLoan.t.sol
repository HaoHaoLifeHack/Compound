// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
//import "../src/BalanceChecker.sol";
import "../src/AaveFlashLoan.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "compound-protocol/SimplePriceOracle.sol";
import "compound-protocol/Comptroller.sol";
import "compound-protocol/ComptrollerInterface.sol";
import "compound-protocol/Unitroller.sol";
import "compound-protocol/CErc20Delegate.sol";
import "compound-protocol/CErc20Delegator.sol";
import "compound-protocol/WhitePaperInterestRateModel.sol";
import "compound-protocol/InterestRateModel.sol";

contract AaveFlashLoanTest is Test {
    //roles
    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address liquidator = makeAddr("liquidator");
    uint256 initialBalance = 100 ether;
    uint256 initialUSDCBalance = 5000 * 1e6;
    uint256 initialUNIBalance = 5000 * 1e18;

    //related contracts
    ERC20 USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    Comptroller comptroller;
    CErc20Delegator cUSDC;
    CErc20Delegator cUNI;
    CErc20Delegate impl;
    WhitePaperInterestRateModel interestRateModel;
    Unitroller unitroller;
    SimplePriceOracle priceOracle;
    AaveFlashLoan public aaveFlashLoan;
    Comptroller comptrollerProxy;

    function setUp() public {
        //fork mainnet at block 17465000
        string memory rpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(rpc, 17465000);
        //assertEq(vm.activeFork(), rpc);
        //vm.rollFork(17465000);
        assertEq(block.number, 17465000);

        // admin auth
        vm.startPrank(admin);
        //create price oracle
        priceOracle = new SimplePriceOracle();

        // //initailize Flashloan function
        // aaveFlashLoan = new AaveFlashLoan();
        // vm.label(address(aaveFlashLoan), "Flash Loan");
        // deal(address(USDC), address(aaveFlashLoan), initialBalance);

        //create unitroller and set comptroller as implementation
        comptroller = new Comptroller();
        unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);

        //create comptroller proxy
        comptrollerProxy = Comptroller(address(unitroller));

        //create basic interestrate model
        interestRateModel = new WhitePaperInterestRateModel(0, 0);

        //create CErc20Delegate
        impl = new CErc20Delegate(); //impl of CErc20Delegator

        //vm.startPrank(admin);
        /**
         * @notice Construct a new money market
         * @param underlying_ The address of the underlying asset
         * @param comptroller_ The address of the Comptroller
         * @param interestRateModel_ The address of the interest rate model
         * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
         * @param name_ ERC-20 name of this token
         * @param symbol_ ERC-20 symbol of this token
         * @param decimals_ ERC-20 decimal precision of this token
         * @param admin_ Address of the administrator of this token
         * @param implementation_ The address of the implementation the contract delegates to
         * @param becomeImplementationData The encoded args for becomeImplementation
         */

        // 使用 USDC 以及 UNI 代幣來作為 token A 以及 Token B
        cUSDC = new CErc20Delegator(
            address(USDC),
            comptrollerProxy,
            interestRateModel,
            1e6, //set exchange rate = 1
            "Compound USDC",
            "cUSDC",
            18,
            payable(admin),
            address(impl),
            ""
        );

        cUNI = new CErc20Delegator(
            address(UNI),
            comptrollerProxy,
            interestRateModel,
            1e18, //mantissa
            "Compound UNI",
            "cUNI",
            18,
            payable(admin),
            address(impl),
            ""
        );

        comptrollerProxy._supportMarket(CToken(address(cUSDC)));
        comptrollerProxy._supportMarket(CToken(address(cUNI)));
        // 在 Oracle 中設定 USDC 的價格為 $1，UNI 的價格為 $5
        comptrollerProxy._setPriceOracle(priceOracle);
        priceOracle.setUnderlyingPrice(CToken(address(cUSDC)), 1e30);
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 5e18);
        // 設定 UNI 的 collateral factor 為 50%
        comptrollerProxy._setCollateralFactor(CToken(address(cUNI)), 5e17);
        // Close factor 設定為 50%
        comptrollerProxy._setCloseFactor(5e17);
        // Liquidation incentive 設為 8%
        comptrollerProxy._setLiquidationIncentive(1.08 * 1e18);

        vm.stopPrank();

        deal(address(USDC), user1, initialUSDCBalance);
        deal(address(USDC), user2, initialUSDCBalance);
        deal(address(USDC), liquidator, initialUSDCBalance);
        deal(address(UNI), user1, initialUNIBalance);
        deal(address(UNI), user2, initialUNIBalance);
        deal(address(UNI), liquidator, initialUNIBalance);
    }

    function testAaveFlashLoan() public {
        _makeInitialLiquidity();

        // User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
        vm.startPrank((user1));
        UNI.approve(address(cUNI), type(uint256).max);
        cUNI.mint(1000 * 1e18);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUNI);
        comptrollerProxy.enterMarkets(cTokens);
        cUSDC.borrow(2500 * 1e6);
        assertEq(USDC.balanceOf(user1), initialUSDCBalance + 2500 * 1e6);
        vm.stopPrank();

        // 將 UNI 價格改為 $4 使 User1 產生 Shortfall，並讓 liquidator 透過 AAVE 的 Flash loan 來借錢清算 User1
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 4e18);
        (, , uint256 shortfall) = comptroller.getAccountLiquidity(user1);
        require(shortfall > 0, "Shortfall should be greater than 0");

        vm.startPrank(liquidator);
        // Close factor 設定為 50% 所以最多幫他還 50% 的借款
        uint256 borrowBalance = cUSDC.borrowBalanceStored(user1);
        uint256 repalyAmount = borrowBalance / 2;

        // 將會用到的參數放入 data
        bytes memory data = abi.encode(cUSDC, cUNI, user1);

        // 執行閃電貸+清算
        aaveFlashLoan = new AaveFlashLoan();
        aaveFlashLoan.execute(address(USDC), repalyAmount, data);

        // 最後從合約領 USDC 出來
        aaveFlashLoan.withdraw(address(USDC));

        // * 可以自行檢查清算 50% 後是不是大約可以賺 63 USDC
        assertGe(USDC.balanceOf(liquidator), 63 * 1e6);
        assertLt(USDC.balanceOf(liquidator), 64 * 1e6);

        vm.stopPrank();
    }

    function _makeInitialLiquidity() private {
        // check market list
        //comptroller.checkMembership(user2, cUSDC);
        // Add liquidity for USDC's pool by user2
        vm.startPrank(user2);

        USDC.approve(address(cUSDC), USDC.balanceOf(user2));
        cUSDC.mint(USDC.balanceOf(user2));
        vm.stopPrank();
    }
}
