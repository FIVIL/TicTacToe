
//// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {TicTacToeV2} from "../src/TicTacToeV2.sol";

contract TicTacToeTestV2 is Test {
    address public immutable p1 = makeAddr("P1");
    address public immutable p2 = makeAddr("P2");
    uint256 public immutable defaultBlockNumber = 19858919;
    uint256 public gameId = 0;
    TicTacToeV2 public game;

    function setUp() public {
        game = new TicTacToeV2();
        game.initialize();
        vm.roll(defaultBlockNumber);
        vm.prank(p1);
        gameId = game.openNewGame(p2, 10);       
    }

    function testAbuse() public {
        vm.roll(defaultBlockNumber + 1);
        vm.prank(p2);
        game.acceptInvite(gameId);

        vm.roll(defaultBlockNumber + 2);
        vm.prank(p2);
        game.Move(gameId, 0, 0);

        vm.roll(defaultBlockNumber + 3);
        vm.prank(p1);
        game.Move(gameId, 0, 1);
        
        vm.prank(p1);
        vm.roll(defaultBlockNumber + 15);
        assertEq(uint256(game.settleAbuse(gameId)),  uint256(TicTacToeV2.GameState.P1Victory));
    }

    function testSingleMovePerBlock() public{
        vm.prank(p2);
        game.acceptInvite(gameId);

        vm.prank(p2);
        vm.expectRevert("Only one move allowed per block.");
        game.Move(gameId, 0, 0);
    }

    function testP1HWin() public {
        vm.prank(p2);
        game.acceptInvite(gameId);

        vm.roll(defaultBlockNumber + 1);
        vm.prank(p2);
        game.Move(gameId, 0, 0);

        vm.roll(defaultBlockNumber + 2);
        vm.prank(p1);
        game.Move(gameId, 0, 1);
        
        vm.roll(defaultBlockNumber + 3);
        vm.prank(p2);
        game.Move(gameId, 0, 2);

        vm.roll(defaultBlockNumber + 4);
        vm.prank(p1);
        game.Move(gameId, 1, 1);

        vm.roll(defaultBlockNumber + 5);
        vm.prank(p2);
        game.Move(gameId, 2, 2);

        vm.roll(defaultBlockNumber + 6);
        vm.prank(p1);
        vm.expectEmit(true, false, false, true);
        emit TicTacToeV2.gameFinished(gameId, p1);
        game.Move(gameId, 2, 1);  
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToeV2.GameState.P1Victory));
        assertEq(game.getBoard(gameId) & 1344, 1344);   
    }
}
