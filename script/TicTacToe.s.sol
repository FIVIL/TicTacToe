
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../src/TicTacToeV3.sol";

contract DeployTickTakToe is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("arbitrum_sepolia", "https://rpc.arb-test.org");
        vm.startBroadcast(deployerPrivateKey);
        TicTacToeV3 gamearbsep = new TicTacToeV3(0xBF62ef1486468a6bd26Dd669C06db43dEd5B849B, 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6);
        console.log("Arbitrum Sepolia Contract Address:", address(gamearbsep));
        vm.stopBroadcast();

        vm.createSelectFork("sepolia", "https://rpc.sepolia.org");
        vm.startBroadcast(deployerPrivateKey);
        TicTacToeV3 gamesep = new TicTacToeV3(0xe432150cce91c13a887f7D836923d5597adD8E31, 0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6);
        console.log("Sepolia Contract Address:", address(gamesep));
        vm.stopBroadcast();
    }
}