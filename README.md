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

# V2

The second version of the game offers several new features:

### Jack Pot
A jack pot enabling the users to bet, in this scenario if the first player puts a bet while creating the game, the 2nd player also has to call the first player betting the same amount of ether, finally at the end of the game the winner takes all the winnings after paying a 10% fee to the contract. 

If no winner is found and the game results in a draw each of the players will receive their original bet minus the contract fee.

### DOS Protection

In order to prevent players from simply not playing their turns if they know their lost is certain, a mechanism have been implemented to automatically nominate the other player as winner after certain number of blocks have been mined. This number of blocks is configurable while creating a new game.

### Front Running Protection

Imagine a scenario when the first player submits a move and then the second player submits their move in the same block, in this scenario the first player can potentially front run their own original transaction and play a more favorable move knowing the second player's move. In order to prevent such attacks, game logic makes sure that only 1 move is allowed per block for each game.

### VRF (not yet implemented)

In the current implementation, it is possible for first user to determine his turn before starting the game and only invite people that will result in a favorable turn for them. However using chainlink VRFs or other random number generator oracles it is possible to truly randomize turn assignment and prevent this issue.

# How To Run

In order to run the game and tests, you need to use **foundry**. 

After cloning the repo and installing the tool, simple run ```forge build``` and ```forge test``` to see the results.


# Security 

In what follows we will discuss the security consideration and implications of the game. Considering game's simple logic and lack of external calls the security implications of threat surface of the contract can be considered fairly limited.

## Threat Model

To understand the potential attack surface of the contract, we first need to identify the possible attackers. In the case of this contract, the most obvious malicious actors could be the players themselves. Each player might attempt to manipulate the contract to gain an unfair advantage or break the contract altogether. Here are some potential attacks that players could attempt:

- **Submitting invalid moves**: Players might try to submit illegal or invalid moves on the game board.
- **Playing out of turn**: Players might attempt to make moves when it's not their turn.
- **Exploiting mining time and transaction pool**: Players might try to gain insight into the other player's move by exploiting mining time and the transaction pool, and then alter their own moves accordingly.
- **Abstaining from playing**: If a player knows the outcome of the game is not in their favor, they might refrain from making any further moves.
- **Withdrawing excessive funds**: Players might attempt to withdraw more funds from the contract than their actual winnings.
- **Draining contract funds**: Players might try to drain all the funds from the contract.
- **Malicious contract upgrade**: Considering the contract's upgradability, players might attempt to upgrade the contract to a new malicious implementation of their own.




