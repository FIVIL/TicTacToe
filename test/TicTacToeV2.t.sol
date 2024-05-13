
//// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {TicTacToeV2} from "../src/TicTacToeV2.sol";

contract TicTacToeTestV2 is Test {
    address public immutable owner = makeAddr("owner");
    address public immutable p1 = makeAddr("P1");
    address public immutable p2 = makeAddr("P2");
    uint256 public immutable defaultBlockNumber = 19858919;
    uint256 public gameId = 0;
    TicTacToeV2 public game;

    function setUp() public {
        game = new TicTacToeV2();
        vm.prank(owner);
        game.initialize();
        vm.roll(defaultBlockNumber);
        vm.prank(p1);
        deal(address(p1), 1 ether);
        deal(address(p2), 1 ether);
        gameId = game.openNewGame{value: 1 ether}(p2, 10); 
        assertEq(address(game).balance, 1 ether);     
    }

    function testAbuse() public {
        vm.roll(defaultBlockNumber + 1);
        vm.prank(p2);
        game.acceptInvite{value: 1 ether}(gameId);
        assertEq(address(game).balance, 2 ether); 

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
        game.acceptInvite{value: 1 ether}(gameId);

        vm.prank(p2);
        vm.expectRevert("Only one move allowed per block.");
        game.Move(gameId, 0, 0);
    }

    function testP1HWin() public {
        vm.prank(p2);
        game.acceptInvite{value: 1 ether}(gameId);

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

    function testP1HWinWithdraw() public {
        vm.prank(p2);
        game.acceptInvite{value: 1 ether}(gameId);

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
        game.Move(gameId, 2, 1);  
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToeV2.GameState.P1Victory));

        assertEq(address(p1).balance, 0);
        assertEq(address(game).balance, 2 ether);
        vm.prank(p1);
        game.withdrawJackpot(gameId);
        assertEq(address(p1).balance, 1.8 ether);
        assertEq(address(game).balance, 0.2 ether);

        assertEq(address(owner).balance, 0);
        vm.prank(owner);
        game.withdrawFees();
        assertEq(address(owner).balance, 0.2 ether);
        assertEq(address(game).balance, 0);
    }

    function testDoubleWithdraw() public {
        vm.prank(p2);
        game.acceptInvite{value: 1 ether}(gameId);

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
        game.Move(gameId, 2, 1);  
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToeV2.GameState.P1Victory));

        vm.prank(p1);
        game.withdrawJackpot(gameId);
        
        vm.expectRevert("You have already withdrawn your funds.");
        vm.prank(p1);
        game.withdrawJackpot(gameId);

    }

    function testWrongWithdraw() public {
        vm.prank(p2);
        game.acceptInvite{value: 1 ether}(gameId);

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
        game.Move(gameId, 2, 1);  
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToeV2.GameState.P1Victory));
        
        vm.expectRevert("You can't withdraw.");
        vm.prank(p2);
        game.withdrawJackpot(gameId);

    }
}
