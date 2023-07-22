// SPDX-License-Identifier: MIT
// Contract manages the ve side of things

// Contract also manages the slashing if users are slashed

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoteContract is Ownable {
    uint public constant DURATION = 7 days;

    IERC20 public constant NGMI = IERC20(0x123);

    mapping(uint256 => mapping(uint256 => VoteSegment)) public VoteSegments;
    struct VoteSegment {
        uint256 votes;
        mapping(address => uint256) deposits;
        uint256 slashedRatio;
    }

    event Vote(address indexed user, uint256 indexed gauge, uint256 epoch);

    function epoch() internal pure returns (uint256) {
        return (block.timestamp / DURATION);
    }

    function deposit(uint256 _gauge, uint256 _amount) external {
        NGMI.transferFrom(msg.sender, address(this), _amount);
        VoteSegment storage voteSegment = VoteSegments[epoch()][_gauge];
        voteSegment.deposits[msg.sender] += _amount;
        voteSegment.votes += _amount;
        emit Vote(msg.sender, _gauge, epoch());
    }

    function withdraw(uint256 _gauge, uint256 _epoch, uint256 _amount) external {
        require(_epoch != epoch() - 1, "tokens locked");
        VoteSegment storage voteSegment = VoteSegments[epoch()][_gauge];
        voteSegment.deposits[msg.sender] -= _amount;
        voteSegment.votes -= _amount;
        NGMI.transfer(msg.sender, _amount * (1e18 - voteSegment.slashedRatio) / 1e18);
    }

    function coverShortfall(uint256 _gauge, uint256 _amount) external onlyOwner {
        VoteSegment storage voteSegment = VoteSegments[epoch()][_gauge];
        NGMI.transfer(owner(), _amount);
        voteSegment.slashedRatio += _amount / voteSegment.votes;
        require(voteSegment.slashedRatio <= 1e18, "overslashed");
    }
}