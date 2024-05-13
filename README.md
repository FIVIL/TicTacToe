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


## Auditing Methodology

In this section we will explore the auditing process that can be used to find this contract and other contracts vulnerabilities, the audit methodology discussed below is simply a personal methodology of the author of this work.

The first step toward a successful audit comes from a deep understanding of the code, my personal method consists of reviewing all the provided documentations by the developers and then diving deep into the code and matching the sections of the documents with the code in order to grasp a complete understanding of the code.

Taking this code as an example, the most complicated part of the code are parts of the code about bit packing and compressing all the state variables in a single **uint256** and performing various unintuitive boolean operations on top of it to store and read the states.

In a scenario like this taking advantage of tools such as ```chisel``` or plain old paper and pen can be a game changer, using these tools an auditor can solve several examples and understand the usage of all binary operations at each part. 
Consider the example below from the ```src/TicTacToeV2.sol:L184~187```. What are the purpose of shifts, why did we need to both shift to right and left in the same line and what will be the end result of bitwise and operation.

```Solidity
  function p2Withdrawed(uint256 _gameSetup) private pure returns (bool){
        return ((_gameSetup & (1 << 185)) >> 185) == 0;
    }
```

Using ```chisel``` and creating a several example with different values will reveal that this code is trying to see if the 186th bit is equal to 0.

At this stage after being able to understand the logic of the contract we can start looking for vulnerabilities and bugs. My personal favorite method is to first try and find as many potential vulnerability as possible and then use a comprehensive checklist such as (solodit)[https://solodit.xyz/checklist] to find all other potential vulnerabilities. During this stage I tend to put my findings around the code in comment, or better yet GitHub review comments if possible.

Although Solidity contracts does not have an exact entrypoint like Solana contracts still determining public and external functions and starting with them can be helpful.

After several rounds of checking and making sure I have found all the vulnerabilities that I could I start the POC phase. At very beginning of this phase I will check the provided tests and then I will try to write several tests for each of the complicated findings to make sure they are valid. Finally, I will start documenting the findings and determining their severity based on the fact that if they can put funds directly in danger or not.

### Possible Vulnerability of this Contract

This contract can have several potential vulnerabilities:

1. **DOS**: As explained above players might abstain from making their moves if they know they will lose and basically make the contract deny service to the other player. In order to address this issue **TicTacToeV2** enables the other user to unilaterally win if one of the players abstain for certain number of blocks.

2. **Front Running**: Players might try to front run their own transaction after seeing other players transaction. To prevent this issue **TicTacToeV2** enforces one move per block rule.

3. **Reentrancy**: The withdraw function could be reentrant in this contract considering the external calls. However, making sure that the state variables are being updated before the call nullifies this attack for this contract.

> The contract also takes advantage of *Checks-Effects-Interactions Pattern* to prevent any potential unexpected behavior. 

4. **Logic**: The logic of the contract could suffer from several vulnerabilities as explored in the beginning of the security section. However, all of these scenarios have been mitigated and the contract have been tested against them.

### Unit testing

Tests can be a great tool to make sure the contract logic works as expected and no vulnerabilities can be found.
We have provided 23 different unit tests for this contract to achieve 81% test coverage. However, considering that many of the v1 tests can be also used for v2 the actual coverage is higher.

| File                | % Lines          | % Statements     | % Branches       | % Funcs        |
|---------------------|------------------|------------------|------------------|----------------|
| src/TicTacToe.sol   | 98.72% (77/78)   | 90.15% (119/132) | 80.30% (53/66)   | 85.71% (12/14) |
| src/TicTacToeV2.sol | 72.67% (109/150) | 69.66% (163/234) | 48.18% (53/110)  | 77.27% (17/22) |
| Total               | 81.58% (186/228) | 77.05% (282/366) | 60.23% (106/176) | 80.56% (29/36) |


### Upgradeability

Adding upgradeability can potentially increase the attack surface of the contract, specially if the developers do not know how the patterns work under the hood and what functions are involved.

In order to add upgradeability to this game we have taken advantage of OpenZeppelin open source contracts using **UUPS Proxy** pattern which can reduce the gas costs by brining the upgrade functions within the implementation contact.

1. **Initializer**: Upgradable contracts use initializers instead of constructors. However, considering that this is simply a function unlike constructors, it is important to make sure they are being called at the right time and only once.

2. **authorizeUpgrade**: The UUPS proxy pattern calls for having this function in all the implementation contracts in order to be able to upgrade them later on. Lack of proper access control enforcement for this function can create a huge vulnerability and enable anyone to upgrade the contract to the implementation of their choosing potentially stealing everything. Also, lack of this function can remove the upgradeability functionality marking that implementation final.

3. **Storage Collisions**: This problem might not be obvious at first cite and **many** developers make mistakes in this regard while implementing their first couple of upgradable contracts. Under the hood all the state variables are going throw binary serialization and then solidity concatenates them together to create the contract storage. Although, very efficient this methods lacks structure that is typically present in other methods of data storage such as json. Without schema, once you make changes to the order of the variables solidity can't track the changes and will end up deserializing wrong values in wrong variables. Therefore, it is very important to make sure storage variables are **ordered** the same across multiple virions of the same contract. Addiotnally, it is highly advised to leave some empty space at the end of the store variables for the potential new storage variables in future virions. Both of these practices have been followed in both versions of TicTacToe game. The storage gap is defined via ```uint256[100] ______gap;``` in the V1 contract.


# Deployment

Considering the sensitivity of smart contracts deploying them requires extra caution.

1. **Multi-Sig wallet**: Considering using multi signature wallets (such as 3 out 5) wallet while deploying important smart contracts to make sure leakage of one private key won't result in a disaster. 

2. **Immutability**: Blockchain is immutable and if an smart contract is deployed with wrong values in constructor or initializer it might have devastating affects since there might not be a way to change them.

3. **Initializer**: While deploying upgradable contracts it is important to pay attention to their initializers. Unlike constructors, initializers are functions, which means they won't be called during contract deployment. Failure to call the initializer during deployment or upgrading the contract can result in malicious actors taking control over the contract by calling the initializer before the actual contract owner. The best way to deploy these sort of contracts is to take advantage of tools like ```hardhat``` and ```forge``` to call the initializer right after contract deployment via the same transaction to make it impossible for anyone else to call it before contract owner or front run the owner.


# Maintenance and Monitoring 