// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IFlashLoanSimpleReceiver, IPoolAddressesProvider, IPool} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import "compound-protocol/CErc20Delegator.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams memory params
    ) external returns (uint256 amountOut);
}

// TODO: Inherit IFlashLoanSimpleReceiver
contract AaveFlashLoan is IFlashLoanSimpleReceiver {
    address constant POOL_ADDRESSES_PROVIDER =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    IPool pool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address owner;
    ERC20 UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    ISwapRouter swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    constructor() {
        owner = msg.sender;
    }

    function execute(
        address asset,
        uint256 amountOut,
        bytes calldata params
    ) external {
        // TODO
        /** @notice flashLoanSimple,
            @param address receiverAddress, 
            @param address asset, 
            @param uint256 amount, 
            @param bytes calldata params, 
            @param uint16 referralCode)  
        **/

        pool.flashLoanSimple(address(this), asset, amountOut, params, 0);
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
        bytes calldata params
    ) external returns (bool) {
        require(
            initiator == address(this),
            "FlashLoanLiquidate: invalid initiator"
        );
        require(
            msg.sender == address(pool),
            "FlashLoanLiquidate: invalid sender"
        );

        (CErc20Delegator cUSDC, CErc20Delegator cUNI, address user) = abi
            .decode(params, (CErc20Delegator, CErc20Delegator, address));

        // 借的 asset 是 USDC，Approve 後才 liquidateBorrow
        ERC20(asset).approve(address(cUSDC), type(uint256).max);
        // 清算後拿到的獎勵是 cUNI，領出來變UNI
        cUSDC.liquidateBorrow(user, amount, cUNI);
        cUNI.redeem(cUNI.balanceOf(address(this)));

        // UNI Approve 後 Swap to USDC
        UNI.approve(address(swapRouter), type(uint256).max);
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(UNI),
                tokenOut: asset,
                fee: 3000, // 0.3%
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: UNI.balanceOf(address(this)),
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        swapRouter.exactInputSingle(swapParams);

        // Approve USDC 給 AAVE Pool 還閃電貸借的錢+手續費
        uint256 amountOwed = amount + premium;
        ERC20(asset).approve(address(pool), amountOwed);

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
