
//// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {TicTacToe} from "../src/TicTacToe.sol";

contract CounterTest is Test {
    address public immutable P1 = makeAddr("P1");
    address public immutable P2 = makeAddr("P2");

    TicTacToe public game;

    function setUp() public {
        game = new TicTacToe();
        game.initialize();
    }

    function testGameExists() public {
        if(game.gameCounter() == 0) {
            vm.expectRevert(bytes("This game does not exists."));
            game.getBoard(0);
        }
    }
}