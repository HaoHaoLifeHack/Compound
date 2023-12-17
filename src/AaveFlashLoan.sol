// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
//import {BalanceChecker} from "./BalanceChecker.sol";
import {IFlashLoanSimpleReceiver, IPoolAddressesProvider, IPool} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

// TODO: Inherit IFlashLoanSimpleReceiver
contract AaveFlashLoan is IFlashLoanSimpleReceiver {
    address constant POOL_ADDRESSES_PROVIDER =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address owner;

    constructor() {
        owner = msg.sender;
    }

    function execute(address asset, uint256 amountOut) external {
        // TODO
        /** @notice flashLoanSimple,
            @param address receiverAddress, 
            @param address asset, 
            @param uint256 amount, 
            @param bytes calldata params, 
            @param uint16 referralCode)  
        **/
        POOL().flashLoanSimple(address(this), asset, amountOut, "", 0);
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata data
    ) external returns (bool) {
        // TODO
        //BalanceChecker checker = abi.decode(data, (BalanceChecker));
        //checker.checkBalance();
        // IERC20(USDC).approve(
        //     address(POOL()),
        //     IERC20(USDC).balanceOf(address(this))
        // );
        return true;
    }

    function withdraw(address token) external {
        require(msg.sender == owner);
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }
}
