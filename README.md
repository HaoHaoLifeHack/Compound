6. 請使用 Foundry 的 fork testing 模式撰寫測試，並使用 AAVE v3 的  Flash loan  來清算 User1，請遵循以下細節：

- Fork Ethereum mainnet at block 17465000([Reference](https://book.getfoundry.sh/forge/fork-testing#examples))
- cERC20 的 decimals 皆為 18，初始 exchangeRate 為 1:1
- Close factor 設定為 50%
- Liquidation incentive 設為 8% (1.08 \* 1e18)
- 使用 USDC 以及 UNI 代幣來作為 token A 以及 Token B
- 在 Oracle 中設定 USDC 的價格為 $1，UNI 的價格為 $5
- 設定 UNI 的 collateral factor 為 50%
- User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
- 將 UNI 價格改為 $4 使 User1 產生 Shortfall，並讓 User2 透過 AAVE 的 Flash loan 來借錢清算 User1
- 可以自行檢查清算 50% 後是不是大約可以賺 63 USDC
- 在合約中如需將 UNI 換成 USDC 可以使用以下程式碼片段：

```solidity
// https://docs.uniswap.org/protocol/guides/swaps/single-swaps

ISwapRouter.ExactInputSingleParams memory swapParams =
  ISwapRouter.ExactInputSingleParams({
    tokenIn: UNI_ADDRESS,
    tokenOut: USDC_ADDRESS,
    fee: 3000, // 0.3%
    recipient: address(this),
    deadline: block.timestamp,
    amountIn: uniAmount,
    amountOutMinimum: 0,
    sqrtPriceLimitX96: 0
  });

// The call to `exactInputSingle` executes the swap.
// swap Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564
uint256 amountOut = swapRouter.exactInputSingle(swapParams);
```
