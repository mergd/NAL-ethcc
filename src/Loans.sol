// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ext/LoanCoordinator.sol";
import {VoteContract} from "./VoteContract.sol";
import {NALToken} from "./NAL.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Loans is Lender, Ownable {
    VoteContract public Vote = VoteContract(0x000000000000000000000000000000000000dEaD);
    NALToken public constant NAL = NALToken(0x000000000000000000000000000000000000dEaD);
    NALToken public constant NGMI = NALToken(0x000000000000000000000000000000000000dEaD);

    uint256 borrowCap = 1000000 * 1e18;

    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public borrows;

    constructor(LoanCoordinator coord) Lender(coord) {}

    struct Auction {
        uint256 id;
        Loan loan;
        uint256 shortfall;
        uint256 timestamp;
    }

    Auction[] public auctions;

    /*
    struct Loan {
    uint256 id;
    address borrower;
    address lender;
    ERC20 collateralToken;
    ERC20 debtToken;
    uint256 collateralAmount;
    uint256 debtAmount;
    uint256 interestRate;
    uint256 startingTime;
    uint256 duration;
    uint256 terms;
    }*/

    function verifyLoan(Loan memory loan, bytes32 data) external override returns (bool) {
        address token = address(loan.collateralToken);
        require(whitelisted[token], "collateral not wl");
        require(address(loan.debtToken) == address(NAL), "not NAL");
        // require HF
        uint256 epoch = Vote.epoch();
        bytes32 hash = (keccak256(abi.encodePacked(token, epoch - 1)));
        borrows[address(loan.collateralToken)] += loan.debtAmount;
        require(borrows[token] <= borrowCap * Vote.votes(hash) / Vote.totalVotes(epoch), "above borrow cap");
        require(loan.interestRate >= borrowAPR(token));
        NAL.mint(loan.borrower, loan.debtAmount);
        return true;
    }

    // apr scales based on the cap utilization
    function borrowAPR(address token) internal view returns (uint256) {
        uint256 epoch = Vote.epoch();
        bytes32 hash = (keccak256(abi.encodePacked(token, epoch - 1)));
        uint256 max = borrowCap * Vote.votes(hash) / Vote.totalVotes(epoch);
        uint256 used = borrows[token];
        return 1e6 * used / max;
    }

    function auctionSettledHook(Loan memory loan, uint256 lenderReturn, uint256 borrowerReturn) external override {
        address token = address(loan.collateralToken);
        borrows[token] -= loan.debtAmount;
        if (loan.debtAmount > lenderReturn) {
            // slash
            startAuction(loan, loan.debtAmount - lenderReturn);
        }
    }

    function startAuction(Loan memory loan, uint256 _shortfall) internal {
        Auction memory newAuction =
        Auction(auctions.length, loan, _shortfall, block.timestamp);
        auctions.push(newAuction);
    }

    function bid(uint256 _auctionId) external {
        Auction memory auction = auctions[_auctionId];
        Loan memory loan = auction.loan;
        address token = address(loan.collateralToken);
        uint256 epoch = Vote.epoch(auction.timestamp);
        uint256 shortfall = auction.shortfall;
        uint256 timepass = block.timestamp - auction.timestamp;
        if (timepass > 1 hours) {
            // shortfall used up
            uint256 shortfallCoverage = Vote.shortfallCoverage(token);
            Vote.coverShortfall(token, shortfallCoverage, epoch);
            NGMI.transfer(msg.sender, shortfallCoverage);
            uint256 amount = (timepass > 2 hours) ? 0 : (2 hours - timepass) * shortfall;
            ERC20(token).transferFrom(msg.sender, address(this), amount);
        } else {
            uint256 shortfallCoverage = Vote.shortfallCoverage(token);
            uint256 amount = (1 hours - timepass) * shortfallCoverage;
            Vote.coverShortfall(token, amount, epoch);
            NGMI.transfer(msg.sender, amount);
            ERC20(token).transferFrom(msg.sender, address(this), shortfall);
        }
    }

    function loanRepaidHook(Loan memory loan) external override {
        borrows[address(loan.collateralToken)] -= loan.debtAmount;
        NAL.burn(NAL.balanceOf(address(this)));
    }

    /**
     * @dev Could be optimized
     * @param loan Pass in a loan struct.
     *      loan.debtAmount == Max Uint -> Max borrowable
     *      loan.collateralAmount == Max Uint -> Min Collateral required
     * @return _interest Provide the interest rate for given params
     * @return _lendAmount Provide the amount that can be borrowed
     * @return _collateral Provide the amount of collateral required
     */
    function getQuote(Loan memory loan) external view override returns (uint256, uint256, uint256) {
        return (0, 0, 0);
    }
}
