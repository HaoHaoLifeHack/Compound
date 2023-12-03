// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/HaoToken.sol";
import "../src/SimplePriceOracle.sol";
import "../src/Comptroller.sol";
import "../src/ComptrollerInterface.sol";
import "../src/Unitroller.sol";
import "../src/CErc20Delegate.sol";
import "../src/CErc20Delegator.sol";
import "../src/WhitePaperInterestRateModel.sol";
import "../src/InterestRateModel.sol";

contract Deploy is Script {
    function run() public {
        vm.startBroadcast();

        //create price oracle
        SimplePriceOracle priceOracle = new SimplePriceOracle();

        //create comptroller
        Comptroller comptroller = new Comptroller();
        comptroller._setPriceOracle(priceOracle);

        //create unitroller and set comptroller as implementation
        Unitroller unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        unitroller._acceptImplementation();

        //create interestrate model
        WhitePaperInterestRateModel interestRateModel = new WhitePaperInterestRateModel(
                0,
                0
            );

        //create CErc20Delegate
        CErc20Delegate cErc20Delegate = new CErc20Delegate();
        ComptrollerInterface comptrollerInterface = ComptrollerInterface(
            address(comptroller)
        );
        InterestRateModel interestRateModelInterface = InterestRateModel(
            address(interestRateModel)
        );
        address payable admin = payable(msg.sender);

        //create token
        HaoToken token = new HaoToken();

        CErc20Delegator cErc20Delegator = new CErc20Delegator(
            address(token),
            comptrollerInterface,
            interestRateModelInterface,
            1,
            "Compound MTK",
            "cMTK",
            18,
            admin,
            address(cErc20Delegate),
            ""
        );
        vm.stopBroadcast();
    }
}
