// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ext/LoanCoordinator.sol";
import {VoteContract} from "./VoteContract.sol";
import {NALToken} from "./NAL.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Loans is Lender, Ownable {
    VoteContract public Vote =
        VoteContract(0x000000000000000000000000000000000000dEaD);
    NALToken public constant NAL =
        NALToken(0x000000000000000000000000000000000000dEaD);

    uint256 borrowCap = 1000000 * 1e18;

    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public borrows;

    constructor(LoanCoordinator coord) Lender(coord) {}

    function verifyLoan(
        Loan memory loan,
        bytes32 data
    ) external override returns (bool) {
        address token = address(loan.collateralToken);
        require(whitelisted[token], "collateral not wl");
        require(address(loan.debtToken) == address(NAL), "not NAL");
        // require HF
        uint256 epoch = Vote.epoch();
        bytes32 hash = (keccak256(abi.encodePacked(token, epoch - 1)));
        borrows[address(loan.collateralToken)] += loan.debtAmount;
        require(
            borrows[token] <=
                (borrowCap * Vote.votes(hash)) / Vote.totalVotes(epoch),
            "above borrow cap"
        );
        require(loan.interestRate >= borrowAPR(token));
        NAL.mint(loan.borrower, loan.debtAmount);
        return true;
    }

    // apr scales based on the cap utilization
    function borrowAPR(address token) internal view returns (uint256) {
        uint256 epoch = Vote.epoch();
        bytes32 hash = (keccak256(abi.encodePacked(token, epoch - 1)));
        uint256 max = (borrowCap * Vote.votes(hash)) / Vote.totalVotes(epoch);
        uint256 used = borrows[token];
        return (1e6 * used) / max;
    }

    function auctionSettledHook(
        Loan memory loan,
        uint256 lenderReturn,
        uint256 borrowerReturn
    ) external override {
        borrows[address(loan.collateralToken)] -= loan.debtAmount;
        if (loan.debtAmount > borrowerReturn) {
            uint256 shortfall = loan.debtAmount - borrowerReturn;
            coverShortfall(address(loan.collateralToken), shortfall);
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
    function getQuote(
        Loan memory loan
    ) external view override returns (uint256, uint256, uint256) {
        return (0, 0, 0);
    }
}
