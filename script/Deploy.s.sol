// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "src/ext/LoanCoordinator.sol";

import {NALToken} from "src/NAL.sol";
import {NGMIToken} from "src/NGMI.sol";
import {VoteContract} from "src/VoteContract.sol";
import {Loans} from "src/Loans.sol";


/// @notice A very simple deployment script
contract Deploy is Script {
    /// @notice The main script entrypoint
    function run() external {
        uint256 privatekey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(privatekey);
        coord = new LoanCoordinator();
        console2.log("Deployed LoanCoordinator at address", address(coord));

        coord.setTerms(Terms(50, 20, 5, 8 hours)); // term 1
        coord.setTerms(Terms(10, 30, 5, 1)); // term 2
        NALToken NAL = new NALToken();
        NGMIToken NGMI = new NGMIToken();
        VoteContract Vote = new VoteContract(address(NGMI));
        Loans Loan = new Loans(address(coord), address(Vote), address(NAL), address(NGMI));
        vm.stopBroadcast();
    }
}
