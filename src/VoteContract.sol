// SPDX-License-Identifier: MIT

// Contract also manages the slashing if users are slashed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoteContract is Ownable {
    uint256 public constant DURATION = 7 days;

    IERC20 public constant NGMI =
        IERC20(0x000000000000000000000000000000000000dEaD);

    mapping(bytes32 => mapping(address => uint256)) public deposits;
    mapping(bytes32 => uint256) public votes;
    mapping(bytes32 => uint256) public slashedRatio;
    mapping(uint256 => uint256) public totalVotes;

    event Vote(address indexed user, address gauge, uint256 epoch);

    function epoch() public view returns (uint256) {
        return epoch(block.timestamp);
    }

    function epoch(uint256 timestamp) public pure returns (uint256) {
        return (timestamp / DURATION);
    }

    function deposit(address _token, uint256 _amount) external {
        NGMI.transferFrom(msg.sender, address(this), _amount);
        bytes32 hash = (keccak256(abi.encodePacked(_token, epoch())));
        deposits[hash][msg.sender] += _amount;
        votes[hash] += _amount;
        totalVotes[epoch()] += _amount;
        emit Vote(msg.sender, _token, epoch());
    }

    function withdraw(
        address _token,
        uint256 _epoch,
        uint256 _amount
    ) external {
        require(_epoch != epoch() - 1, "tokens are locked");
        bytes32 hash = (keccak256(abi.encodePacked(_token, _epoch)));
        deposits[hash][msg.sender] -= _amount;
        votes[hash] -= _amount;
        totalVotes[_epoch] -= _amount;
        NGMI.transfer(
            msg.sender,
            (_amount * (1e18 - slashedRatio[hash])) / 1e18
        );
    }

<<<<<<< HEAD
    function shortfallCoverage(address _token) public view returns (uint256) {
=======
    function coverShortfall(
        address _token,
        uint256 _amount
    ) external onlyOwner {
>>>>>>> 781edc0b5abba4ad5664226ecfa6cccba6022a18
        bytes32 hash = (keccak256(abi.encodePacked(_token, epoch() - 1)));
        return (1e18 - slashedRatio[hash]) * votes[hash];
    }

    function coverShortfall(address _token, uint256 _amount, uint256 _epoch) external onlyOwner {
        bytes32 hash = (keccak256(abi.encodePacked(_token, _epoch)));
        // if amount > avaliable
        uint256 safeAmount = _min(
            _amount,
            (1e18 - slashedRatio[hash]) * votes[hash]
        );
        NGMI.transfer(owner(), safeAmount);
        slashedRatio[hash] += (safeAmount * 1e18) / votes[hash];
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}
