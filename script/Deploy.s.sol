// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/HaoToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "compound-protocol/SimplePriceOracle.sol";
import "compound-protocol/Comptroller.sol";
import "compound-protocol/ComptrollerInterface.sol";
import "compound-protocol/Unitroller.sol";
import "compound-protocol/CErc20Delegate.sol";
import "compound-protocol/CErc20Delegator.sol";
import "compound-protocol/WhitePaperInterestRateModel.sol";
import "compound-protocol/InterestRateModel.sol";

contract Deploy is Script {
    ERC20 tokenA;
    ERC20 tokenB;
    Comptroller comptroller;
    CErc20Delegator cTokenA;
    CErc20Delegator cTokenB;
    CErc20Delegate impl;
    WhitePaperInterestRateModel model;
    Unitroller unitroller;
    SimplePriceOracle priceOracle;

    function run() public {
        vm.startBroadcast();
        _deploy(msg.sender);
        vm.stopBroadcast();
    }

    function _deploy(address admin) internal {
        tokenA = new HaoTokenA();
        tokenB = new HaoTokenB();

        //create price oracle
        priceOracle = new SimplePriceOracle();

        //create unitroller and set comptroller as implementation
        unitroller = new Unitroller();
        comptroller = new Comptroller();
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        unitroller._acceptImplementation();

        //create basic interestrate model
        WhitePaperInterestRateModel interestRateModel = new WhitePaperInterestRateModel(
                0,
                0
            );

        //create comptroller proxy
        Comptroller comptrollerProxy = Comptroller(address(unitroller));
        comptrollerProxy._setPriceOracle(priceOracle);

        //create CErc20Delegate
        CErc20Delegate cErc20Delegate = new CErc20Delegate(); //impl of CErc20Delegator

        cTokenA = new CErc20Delegator(
            address(tokenA),
            comptrollerProxy,
            interestRateModel,
            1e18, //mantissa
            "Compound HaoTokenA",
            "cHTA",
            18,
            payable(admin),
            address(cErc20Delegate),
            ""
        );

        cTokenB = new CErc20Delegator(
            address(tokenB),
            comptrollerProxy,
            interestRateModel,
            1e18, //mantissa
            "Compound HaoTokenB",
            "cHTB",
            18,
            payable(admin),
            address(cErc20Delegate),
            ""
        );

        comptrollerProxy._supportMarket(CToken(address(cTokenA)));
        comptrollerProxy._supportMarket(CToken(address(cTokenB)));

        // In Compound V2 doc：The price of the asset in USD as an unsigned integer scaled up by 10 ^ (36 - underlying asset decimals). E.g. WBTC has 8 decimal places, so the return value is scaled up by 1e28.
        comptrollerProxy._setPriceOracle(priceOracle);
        // set cTokenA = 1 USD
        priceOracle.setUnderlyingPrice(CToken(address(cTokenA)), 1e18);
        // set cTokenB = 100 USD
        priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 1e20);

        comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)), 5e17);
        comptrollerProxy._setCloseFactor(5e17);
        comptrollerProxy._setLiquidationIncentive(1.10 * 1e18);
    }
}
