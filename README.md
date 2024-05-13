# TicTacToe On chain

This repository contains an optimized implementation of the **Tic Tac Toe** game using **solidity** langue deployable on top of **Ethereum** Blockchain.

The implementation follows **UUPS upgradable proxy pattern** for smart contract upgradeability and two versions of the game have been developed with **V2** being more advanced with several new feature and security considerations.

The game also supports **concurrency** and several games can exists within the contract at different stages with different players. 

# Optimization

In order to optimize the storage requirements of the game and reduce the gas cost of several necessary actions of the game such as determining  winner bit packing method have been used. Using this method the entire game board as well as other flags and state variables of the game have been packed into a single **uint256** drastically improving the game gas cost and storage requirements.

## Bit Mapping

- The first 18 bit of the **gameSetup** contains the game board. TicTacToe game board normally consists of a 3 * 3 matrix with 9 spots. In this implementation we have assigned two bits for each of the spots in the matrix, setting the first bit in the spot indicates an **X** (i.e., player 1 have market that spot) and setting the second bit indicated an **O** (i.e., player 2 have market that spot).
- The 19th bit indicates user's turn, if the bit is set the 2nd player should play and if the bit it reset the first player can play.
- The next 3 bits indicate the state of the current state of the game:
    - **0 0 0**: The game have been created but not initialized meaning the second player have not joined the game yet.
    - **1 0 0**: The game is in progress with both players in the game.