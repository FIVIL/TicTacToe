# TicTacToe On chain

This repository contains an optimized implementation of the **Tic Tac Toe** game using **solidity** language deployable on top of **Ethereum** Blockchain.

The implementation follows **UUPS upgradable proxy pattern** for smart contract upgradeability and two versions of the game have been developed, with **V2** being more advanced with several new feature and security considerations.

The game also supports **concurrency** and several games can exist within the contract at different stages with different players. 

# Optimization

In order to optimize the storage requirements of the game and reduce the gas cost, several necessary actions of the game, such as determining the winner bit packing method, have been used. Using this method, the entire game board as well as other flags and state variables of the game have been packed into a single **uint256** drastically improving the game gas cost and storage requirements.

### Bit Mapping

The first 18 bits of the **gameSetup** contain the game board. A TicTacToe game board normally consists of a 3 x 3 matrix with 9 spots. In this implementation, we have assigned two bits for each spot in the matrix. Setting the first bit indicates an **X** (player 1 has marked that spot), and setting the second bit indicates an **O** (player 2 has marked that spot).

The 19th bit indicates the user's turn. If the bit is set, the second player should play, and if it is reset, the first player can play.

The next 3 bits indicate the current state of the game:

- **0 0 0**: The game has been created but not initialized, meaning the second player has not joined the game yet.
- **1 0 0**: The game is in progress with both players in the game.
- **1 1 0**: The game has completed, and player 1 won.
- **1 0 1**: The game has completed, and player 2 won.
- **1 1 1**: The game has completed, and neither player won (a tie).

The 23rd bit indicates whether the game exists or not.

The rest of the bits have been used in the **V2** version for representing the block offset, block number, jackpot, and whether players have withdrawn their funds from the jackpot. Many bits are still empty and can be used in later versions of the game.

#### Game Play

The contract allows any user willing to pay the gas fees to initiate a game and invite another player. Once the second player accepts the invitation, the game begins, and players take turns making moves. To determine the first player, the contract concatenates the addresses of both players, hashes the result using the **keccak256** hash function, and assigns the first turn based on the first bit of the hash value.

After each turn, the code checks for a winner or a draw. To check for a winner, the contract uses 18 different bitmasks to evaluate all possible winning scenarios. If none of the winning scenarios match, the contract checks if the board is full, indicating a draw.

The game ends when a winner is found or when the board is full, resulting in a draw.