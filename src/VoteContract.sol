// SPDX-License-Identifier: MIT
// Contract manages the ve side of things

// Contract also manages the slashing if users are slashed

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoteContract is Ownable {
    uint public constant DURATION = 7 days;

    IERC20 public constant NGMI = IERC20(0x123);

    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public deposits;
    mapping(uint256 => mapping(uint256 => uint256)) public votes;
    mapping(uint256 => mapping(uint256 => uint256)) public slashedRatio;

    event Vote(address indexed user, uint256 indexed gauge, uint256 epoch);

    function epoch() internal pure returns (uint256) {
        return (block.timestamp / DURATION);
    }

    function deposit(uint256 _gauge, uint256 _amount) external {
        NGMI.transferFrom(msg.sender, address(this), _amount);
        deposits[msg.sender][_gauge][epoch()] += _amount;
        votes[_gauge][epoch()] += _amount;
        emit Vote(msg.sender, _gauge, epoch());
    }

    function withdraw(uint256 _gauge, uint256 _epoch, uint256 _amount) external {
        require(_epoch != epoch() - 1, "tokens locked");
        deposits[msg.sender][_gauge][_epoch] -= _amount;
        votes[_gauge][_epoch] -= _amount;
        NGMI.transfer(msg.sender, _amount * (1e18 - slashedRatio[_gauge][_epoch]) / 1e18);
    }

    function coverShortfall(uint256 _gauge, uint256 _amount) external onlyOwner {
        NGMI.transfer(owner(), _amount);
        slashedRatio[_gauge][epoch()] += _amount / votes[_gauge][epoch()];
    }
}