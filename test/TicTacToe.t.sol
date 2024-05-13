
//// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {TicTacToe} from "../src/TicTacToe.sol";

contract TicTacToeTest is Test {
    //p1 & p2 => p1 is O
    //p1 & p3 => p1 is X
    address public immutable p1 = makeAddr("P1");
    address public immutable p2 = makeAddr("P2");
    address public immutable p3 = makeAddr("P3");

    TicTacToe public game;

    function setUp() public {
        console.log(uint256(keccak256(abi.encodePacked(p1, p2))));
        console.log(uint256(keccak256(abi.encodePacked(p1, p3))));
        game = new TicTacToe();
        game.initialize();
    }

    function testGameExists() public {
        if(game.gameCounter() == 0) {
            vm.expectRevert("This game does not exists.");
            game.getBoard(0);
        }
    }

    function testCreateGameP2Turn() public {
        vm.prank(p1);
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.newGame(0, p1, p2);
        uint256 gameId = game.openNewGame(p2);
        assertEq(gameId, 0);
        assertEq(game.getBoard(gameId), ((1 << 22) | (1 << 18)));
    }

    function testCreateGameP1Turn() public {
        vm.prank(p1);
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.newGame(0, p1, p3);
        uint256 gameId = game.openNewGame(p3);
        assertEq(gameId, 0);
        assertEq(game.getBoard(gameId), (1 << 22));   
    }

    function testWrongPlayerJoin() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p3);
        vm.expectRevert("You can't join this game.");
        game.acceptInvite(gameId);
    }

    function testRejoin() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);
        vm.expectRevert("This game does not accept new players at this time.");
        vm.prank(p2);
        game.acceptInvite(gameId);
    }

    function testSucessfulJoin() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.Open));
        vm.prank(p2);
        vm.expectEmit(true, false, false, false);
        emit TicTacToe.playerJoined(0);
        game.acceptInvite(gameId);
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.InProgress));
    }

    function testInvalidMove() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);
        vm.expectRevert("Invalid Move.");
        game.Move(gameId, 3, 0);
    }

    function testInvalidGameState() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        vm.expectRevert("This game is not in progress.");
        game.Move(gameId, 0, 0);
    }

    function testUnauthorizedMove() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);
        vm.prank(p3);
        vm.expectRevert("You are either not part of the game or it is not your turn.");
        game.Move(gameId, 0, 0);
    }

    function testWrongTurn() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);
        vm.prank(p1);
        vm.expectRevert("You are either not part of the game or it is not your turn.");
        game.Move(gameId, 0, 0);
    }

    function testReplayMove() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);
        vm.prank(p2);
        game.Move(gameId, 0, 0);
        vm.prank(p1);
        vm.expectRevert("Move already played.");
        game.Move(gameId, 0, 0);
    }

    function testP1HWin() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);

        // 0 0 p2
        // 0 0 0
        // 0 0 0
        vm.prank(p2);
        game.Move(gameId, 0, 0);

        // 0 0 p2
        // 0 0 p1
        // 0 0 0
        vm.prank(p1);
        game.Move(gameId, 0, 1);
        

        // 0 0 p2
        // 0 0 p1
        // 0 0 p2
        vm.prank(p2);
        game.Move(gameId, 0, 2);

        // 0 0 p2
        // 0 p1 p1
        // 0 0 p2
        vm.prank(p1);
        game.Move(gameId, 1, 1);

        // 0 0 p2
        // 0 p1 p1
        // p2 0 p2
        vm.prank(p2);
        game.Move(gameId, 2, 2);

        // 0 0 p2
        // p1 p1 p1
        // p2 0 p2
        vm.prank(p1);
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.gameFinished(gameId, p1);
        game.Move(gameId, 2, 1);  
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.P1Victory));
        assertEq(game.getBoard(gameId) & 1344, 1344);   
    }

    function testP2VWin() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);

        // 0 0 p2
        // 0 0 0
        // 0 0 0
        vm.prank(p2);
        game.Move(gameId, 0, 0);

        // 0 0 p2
        // 0 p1 0
        // 0 0 0
        vm.prank(p1);
        game.Move(gameId, 1, 1);
        

        // 0 0 p2
        // 0 p1 0
        // 0 0 p2
        vm.prank(p2);
        game.Move(gameId, 0, 2);

        // 0 0 p2
        // p1 p1 0
        // 0 0 p2
        vm.prank(p1);
        game.Move(gameId, 2, 1);

        // 0 0 p2
        // p1 p1 p2
        // p2 0 p2
        vm.prank(p2);
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.gameFinished(gameId, p2);
        game.Move(gameId, 0, 1);
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.P2Victory));
        assertEq(game.getBoard(gameId) & 8322, 8322);   
    }

    function testP2DWin() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);

        // 0 0 p2
        // 0 0 0
        // 0 0 0
        vm.prank(p2);
        game.Move(gameId, 0, 0);

        // 0 p1 p2
        // 0 0 0
        // 0 0 0
        vm.prank(p1);
        game.Move(gameId, 1, 0);
        

        // 0 p1 p2
        // 0 p2 0
        // 0 0 0
        vm.prank(p2);
        game.Move(gameId, 1, 1);

        // p1 p1 p2
        // 0 p2 0
        // 0 0 0
        vm.prank(p1);
        game.Move(gameId, 2, 0);

        // p1 p1 p2
        // 0 p2 0
        // p2 0 0
        vm.prank(p2);
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.gameFinished(gameId, p2);
        game.Move(gameId, 2, 2);
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.P2Victory));
        assertEq(game.getBoard(gameId) & 131586, 131586);
    }

    function testP1DWin() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p3);
        vm.prank(p3);
        game.acceptInvite(gameId);

        // p1 0 0
        // 0 0 0
        // 0 0 0
        vm.prank(p1);
        game.Move(gameId, 2, 0);

        // p1 p3 0
        // 0 0 0
        // 0 0 0
        vm.prank(p3);
        game.Move(gameId, 1, 0);

        // p1 p3 0
        // 0 p1 0
        // 0 0 0
        vm.prank(p1);
        game.Move(gameId, 1, 1);

        // p1 p3 p3
        // 0 p1 0
        // 0 0 0
        vm.prank(p3);
        game.Move(gameId, 0, 0);

        // p1 p3 p3
        // 0 p1 0
        // 0 0 p1
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.gameFinished(gameId, p1);
        vm.prank(p1);
        game.Move(gameId, 0, 2);
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.P1Victory));
        assertEq(game.getBoard(gameId) & 4368, 4368);   
    }

    function testDraw() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p2);
        game.acceptInvite(gameId);

        // p1 p2 p1
        // p2 p1 p2
        // p2 p1 p2

        vm.prank(p2);
        game.Move(gameId, 1, 0);

        vm.prank(p1);
        game.Move(gameId, 0, 0);

        vm.prank(p2);
        game.Move(gameId, 0, 1);

        vm.prank(p1);
        game.Move(gameId, 2, 0);

        vm.prank(p2);
        game.Move(gameId, 2, 1);

        vm.prank(p1);
        game.Move(gameId, 1, 1);

        vm.prank(p2);
        game.Move(gameId, 0, 2);

        vm.prank(p1);
        game.Move(gameId, 1, 2);

        vm.prank(p2);
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.gameFinished(gameId, address(0));
        game.Move(gameId, 2, 2);
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.Draw));    
    }

    function testConcurrentGames() public {
        vm.prank(p1);
        uint256 gameId = game.openNewGame(p2);
        vm.prank(p1);
        uint256 gameId2 = game.openNewGame(p3);
        vm.prank(p2);
        game.acceptInvite(gameId);
        vm.prank(p3);
        game.acceptInvite(gameId2);

        vm.prank(p2);
        game.Move(gameId, 0, 0);

        vm.prank(p1);
        game.Move(gameId2, 2, 0);

        vm.prank(p1);
        game.Move(gameId, 1, 0);

        vm.prank(p3);
        game.Move(gameId2, 1, 0);
        
        vm.prank(p2);
        game.Move(gameId, 1, 1);

        vm.prank(p1);
        game.Move(gameId2, 1, 1);

        vm.prank(p3);
        game.Move(gameId2, 0, 0);

        vm.prank(p1);
        game.Move(gameId, 2, 0);

        vm.prank(p2);
        vm.expectEmit(true, false, false, true);
        emit TicTacToe.gameFinished(gameId, p2);
        game.Move(gameId, 2, 2);
        assertEq(uint256(game.getGameState(gameId)), uint256(TicTacToe.GameState.P2Victory));
        assertEq(game.getBoard(gameId) & 131586, 131586);

        vm.expectEmit(true, false, false, true);
        emit TicTacToe.gameFinished(gameId2, p1);
        vm.prank(p1);
        game.Move(gameId2, 0, 2);
        assertEq(uint256(game.getGameState(gameId2)), uint256(TicTacToe.GameState.P1Victory));
        assertEq(game.getBoard(gameId2) & 4368, 4368);  

    }
}