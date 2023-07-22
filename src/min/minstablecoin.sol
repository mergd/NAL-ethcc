// // SPDX-License-Identifier: MIT
// import "../ext/LoanCoordinator.sol";
// import {ERC20} from "@solmate/tokens/ERC20.sol";

// contract SimpleStablecoin is ERC20, Lender {
//     ERC20 public immutable collateral;

//     constructor(ERC20 _collateral, LoanCoordinator _coordinator) ERC20("Min", "MIN", 18) Lender(_coordinator) {
//         collateral = _collateral;
//     }

//     // need a loan initialized, and then
//     // find the highest unliquidated loan
//     // anyone can make loan +- 3% of that high watermark
//     function verifyLoan(Loan memory loan, bytes32 data) external override returns (bool) {}

//     // avoid needing to go into a loop - maybe autoselect best possible loan
//     function liquidateLoan(uint256 loanId) external {}

//     function loanRepaidHook(Loan memory loan) external override {}

//     function checkLUP() public returns (uint256) {}

//     function auctionSettledHook(Loan memory loan, uint256 lenderReturn, uint256 borrowerReturn) external override {}

//     function addLiquidatorCollateral(uint256 amount) external {}

//     function removeLiquidatorCollateral(uint256 amount) external {}

//     function calculateRatio(uint256 debtAmt, uint256 collateralAmt) private pure returns (uint256) {
//         return (debtAmt * SCALAR) / collateralAmt;
//     }

//     function updateLUP(uint256 _lup) private {}
// }
