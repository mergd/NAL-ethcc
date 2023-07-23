// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {LoanCoordinator, Terms} from "src/ext/LoanCoordinator.sol";

import {NALToken} from "src/NAL.sol";
import {NGMIToken} from "src/NGMI.sol";
import {VoteContract, ERC20} from "src/VoteContract.sol";
import {Loans} from "src/Loans.sol";
import {PSMArranger} from "src/PSMArranger.sol";
import {MockERC20} from "src/mintableERC20.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    /// @notice The main script entrypoint
    function run() external {
        uint256 privatekey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(privatekey);
        LoanCoordinator coord = new LoanCoordinator();
        console2.log("Deployed LoanCoordinator at address", address(coord));

        coord.setTerms(Terms(50, 20, 5, 8 hours)); // term 1
        coord.setTerms(Terms(10, 30, 5, 1)); // term 2
        NALToken NAL = new NALToken();
        console2.log("Deployed NALToken at address", address(NAL));
        NGMIToken NGMI = new NGMIToken();
        console2.log("Deployed NGMIToken at address", address(NGMI));
        VoteContract Vote = new VoteContract(ERC20(address(NGMI)));
        console2.log("Deployed VoteContract at address", address(Vote));
        MockERC20 DAI = new MockERC20("DAI", "DAI");
        console2.log("Deployed MockERC20 at address", address(DAI));
        PSMArranger PSM = new PSMArranger(address(NGMI), address(DAI));
        console2.log("Deployed PSMArranger at address", address(PSM));
        Loans Loan = new Loans(coord, Vote, NAL, NGMI, address(PSM));
        console2.log("Deployed Loans at address", address(Loan));
        vm.stopBroadcast();
    }
}
