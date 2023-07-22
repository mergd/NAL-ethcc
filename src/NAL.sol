// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NALToken is ERC20, Ownable {
    constructor() ERC20("NAL Stablecoin", "NAL", 18) {
        _mint(msg.sender, 100000 * 10 ** 18);
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
