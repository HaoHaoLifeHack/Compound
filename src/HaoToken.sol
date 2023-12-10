// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HaoTokenA is ERC20 {
    constructor() ERC20("HaoTokenA", "HTA") {}

    function mint(address account) external {
        _mint(account, 100 * 10 ** 18);
    }
}

contract HaoTokenB is ERC20 {
    constructor() ERC20("HaoTokenB", "HTB") {}

    function mint(address account) external {
        _mint(account, 100 * 10 ** 18);
    }
}
