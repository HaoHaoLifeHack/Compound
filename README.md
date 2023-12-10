1. 讓 User1 mint/redeem cERC20，請透過 Foundry test case (你可以繼承上題的 script 或是用其他方式實現部署) 實現以下場景：
   - User1 使用 100 顆（100 \* 10^18） ERC20 去 mint 出 100 cERC20 token，再用 100 cERC20 token redeem 回 100 顆 ERC20
2. 讓 User1 borrow/repay
   - 部署第二份 cERC20 合約，以下稱它們的 underlying tokens 為 token A 與 token B。
   - 在 Oracle 中設定一顆 token A 的價格為 $1，一顆 token B 的價格為 $100
   - Token B 的 collateral factor 為 50%
   - User1 使用 1 顆 token B 來 mint cToken
   - User1 使用 token B 作為抵押品來借出 50 顆 token A
3. 延續 (3.) 的借貸場景，調整 token B 的 collateral factor，讓 User1 被 User2 清算
4. 延續 (3.) 的借貸場景，調整 oracle 中 token B 的價格，讓 User1 被 User2 清算
