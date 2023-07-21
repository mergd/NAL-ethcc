// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract NALToken is ERC20 {
    constructor() ERC20("NAL Token", "NAL", 18) {}

    function mint() external returns (uint256) {}
}
