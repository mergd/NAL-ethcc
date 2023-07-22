// SPDX-License-Identifier: MIT
// Contract manages the ve side of things

// Contract also manages the slashing if users are slashed

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoteContract is Ownable {
    uint public constant DURATION = 7 days;

    IERC20 public constant NGMI = IERC20(0x000000000000000000000000000000000000dEaD);

    mapping(bytes32 => mapping(address => uint256)) public deposits;
    mapping(bytes32 => uint256) public votes;
    mapping(bytes32 => uint256) public slashedRatio;
    mapping(uint256 => uint256) public totalVotes;

    event Vote(address indexed user, address gauge, uint256 epoch);

    function epoch() public view returns (uint256) {
        return (block.timestamp / DURATION);
    }

    function deposit(address _token, uint256 _amount) external {
        NGMI.transferFrom(msg.sender, address(this), _amount);
        bytes32 hash = (keccak256(abi.encodePacked(_token, epoch())));
        deposits[hash][msg.sender] += _amount;
        votes[hash] += _amount;
        totalVotes[epoch()] += _amount;
        emit Vote(msg.sender, _token, epoch());
    }

    function withdraw(address _token, uint256 _epoch, uint256 _amount) external {
        require(_epoch != epoch() - 1, "tokens are locked");
        bytes32 hash = (keccak256(abi.encodePacked(_token, _epoch)));
        deposits[hash][msg.sender] -= _amount;
        votes[hash] -= _amount;
        totalVotes[_epoch] -= _amount;
        NGMI.transfer(msg.sender, _amount * (1e18 - slashedRatio[hash]) / 1e18);
    }

    function coverShortfall(address _token, uint256 _amount) external onlyOwner {
        NGMI.transfer(owner(), _amount);
        bytes32 hash = (keccak256(abi.encodePacked(_token, _epoch)));
        slashedRatio[hash] += _amount / votes[_token][epoch()];
    }
}