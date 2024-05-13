//// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";

contract TicTacToeV2 is Initializable, OwnableUpgradeable, MulticallUpgradeable, UUPSUpgradeable {

    uint256 public constant HR1P1M = 21;     //0b 00 00 00 00 00 00 01 01 01
    uint256 public constant HR2P1M = 1344;   //0b 00 00 00 01 01 01 00 00 00
    uint256 public constant HR3P1M = 86016;  //0b 01 01 01 00 00 00 00 00 00
    uint256 public constant HR1P2M = 42;     //0b 00 00 00 00 00 00 10 10 10
    uint256 public constant HR2P2M = 2688;   //0b 00 00 00 10 10 10 00 00 00
    uint256 public constant HR3P2M = 172032; //0b 10 10 10 00 00 00 00 00 00

    uint256 public constant VC1P1M = 66576;  //0b 01 00 00 01 00 00 01 00 00
    uint256 public constant VC2P1M = 16644;  //0b 00 01 00 00 01 00 00 01 00
    uint256 public constant VC3P1M = 4161;   //0b 00 00 01 00 00 01 00 00 01
    uint256 public constant VC1P2M = 133152; //0b 10 00 00 10 00 00 10 00 00
    uint256 public constant VC2P2M = 33288;  //0b 00 10 00 00 10 00 00 10 00
    uint256 public constant VC3P2M = 8322;   //0b 00 00 10 00 00 10 00 00 10

    uint256 public constant DLRP1M = 65793;  //0b 01 00 00 00 01 00 00 00 01
    uint256 public constant DLRP2M = 131586; //0b 10 00 00 00 10 00 00 00 10

    uint256 public constant DRLP1M = 4368;  //0b 00 00 01 00 01 00 01 00 00
    uint256 public constant DRLP2M = 8736;  //0b 00 00 10 00 10 00 10 00 00

    enum GameState { Open, InProgress, /*Completed states:*/ P1Victory, P2Victory, Draw }

    //Game Board stracture
    // # 2 1 0
    // 0 - - -
    // 1 - - -
    // 2 - - -
    struct Game {
        uint256 gameSetup;
        address P1;
        address P2;
    }

    mapping (uint256 => Game) games;
    uint256 public gameCounter = 0;
    uint256 public fees = 0;
    uint256 public constant jackPotMask = 0xFFFFFFFFFFFFFFFFFFFFFF;
    uint256 public constant blockNumberMask = 0xFFFFFFFFF;
    uint256 public constant blockOffsetMask = 0xFFFFF;
    uint256[96] ______gap;

    function loadGame(uint256 _game) private view  returns (Game memory){
        Game memory currentGame = games[_game];
        require(currentGame.gameSetup != 0, "This game does not exists.");
        return currentGame;
    }

    function getGameState(uint256 _game) public view returns (GameState){   
        return gameState(loadGame(_game).gameSetup);
    }

    function getTurn(uint256 _game) public view returns (uint256){
        return (loadGame(_game).gameSetup >> 18 & 1);
    }

    function getBoard(uint256 _game) public view returns (uint256){
        return loadGame(_game).gameSetup;
    }

    function player1Turn(uint256 _gameSetup) private pure returns (bool){
        return (_gameSetup >> 18 & 1) == 0;
    }

    // 21 20 19
    // 0  0  0 => open
    // 1  0  0 => In progress
    // -  1  0 => p1V
    // -  0  1 => p2v
    // -  1  1 => d
    function gameState(uint256 _gameSetup) private pure returns (GameState state){
        if(_gameSetup & (1 << 19) == 0){
            if(_gameSetup & (1 << 20) == 0) {
                if(_gameSetup & (1 << 21) == 0) state = GameState.Open;
                else state = GameState.InProgress;
            } else {
                state = GameState.P1Victory;
            }
        } else {
            if(_gameSetup & (1 << 20) == 0) state = GameState.P2Victory;
            else state = GameState.Draw;
        }
    }

    event gameFinished(uint256 indexed _game, address _winner);
    function Move(uint256 _game, uint8 _x, uint8 _y) public returns (GameState) {
        uint256 move = _y * 3 + _x;  
        require(_x < 3, "Invalid Move.");
        require(_y < 3, "Invalid Move.");
        Game memory currentGame = loadGame(_game);
        require(gameState(currentGame.gameSetup) == GameState.InProgress, "This game is not in progress.");
        bool p1Turn = player1Turn(currentGame.gameSetup);
        require((p1Turn && currentGame.P1 == msg.sender) || (!p1Turn && currentGame.P2 == msg.sender), "You are either not part of the game or it is not your turn.");
        require(getBlockNumber(currentGame.gameSetup) < block.number, "Only one move allowed per block.");
        uint256 playerMoveIndicator = (p1Turn ? 0 : 1);
        move = move << 1;
        require((currentGame.gameSetup & (1 << move) == 0) && ((currentGame.gameSetup & (1 << (move + 1))) == 0), "Move already played.");
        currentGame.gameSetup = currentGame.gameSetup ^ (1 << (move + playerMoveIndicator));
        currentGame.gameSetup = currentGame.gameSetup ^ (1 << 18);

        //In p1Turn, only p1 can win the game and vice versa
        if(p1Turn){
            if(currentGame.gameSetup & HR1P1M == HR1P1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & HR2P1M == HR2P1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & HR3P1M == HR3P1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & VC1P1M == VC1P1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & VC2P1M == VC2P1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & VC3P1M == VC3P1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & DLRP1M == DLRP1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & DRLP1M == DRLP1M) currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
        } else {
            if(currentGame.gameSetup & HR1P2M == HR1P2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & HR2P2M == HR2P2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & HR3P2M == HR3P2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & VC1P2M == VC1P2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & VC2P2M == VC2P2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & VC3P2M == VC3P2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & DLRP2M == DLRP2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else if(currentGame.gameSetup & DRLP2M == DRLP2M) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
        }

        GameState state = gameState(currentGame.gameSetup);
        if(state != GameState.InProgress){
            if(state == GameState.P1Victory) emit gameFinished(_game, currentGame.P1);
            if(state == GameState.P2Victory) emit gameFinished(_game, currentGame.P2);
            games[_game] = currentGame;
            return state;
        }
        uint256 gameSetup = currentGame.gameSetup;
        unchecked {
            for(uint256  i= 0; i<9; ++i){
                //get only the last two digit 3 => 11
                if((gameSetup & 3) == 0) {
                    games[_game] = currentGame;
                    return state;
                }
                gameSetup = gameSetup >> 2;
            }
        }

        currentGame.gameSetup = setDraw(currentGame.gameSetup);
        emit gameFinished(_game, address(0));
        games[_game] = currentGame;
        return GameState.Draw;
    }

    function setP1Winner(uint256 _gameSetup) private pure returns (uint256) {
        return _gameSetup | (1 << 20);
    }

    function setP2Winner(uint256 _gameSetup) private pure returns (uint256) {
        return _gameSetup | (1 << 19);
    }

    function setDraw(uint256 _gameSetup) private pure returns (uint256){
        return (_gameSetup | (1 << 19)) | (1 << 20);
    }

    function getBlockOffset(uint256 _gameSetup) private pure returns (uint256){
        return (_gameSetup & (blockOffsetMask << 23)) >> 23;
    }

    function getBlockNumber(uint256 _gameSetup) private pure returns (uint256){
        return (_gameSetup & (blockNumberMask << 44)) >> 44;
    }

    function getJackPotValue(uint256 _gameSetup) private pure returns (uint256){
        return (_gameSetup & (jackPotMask << 84)) >> 84;
    }

    function p1Withdrawed(uint256 _gameSetup) private pure returns (bool){
        return ((_gameSetup & (1 << 184)) >> 184) == 0;
    }

    function p2Withdrawed(uint256 _gameSetup) private pure returns (bool){
        return ((_gameSetup & (1 << 185)) >> 185) == 0;
    }


    event newGame(uint256 indexed _game, address _p1, address _p2);
    function openNewGame(address _p2, uint256 blockOffset) public payable returns(uint256 gameId){
        //require(msg.sender != _p2, "You can't invite yourself to play");

        bool p1O = (uint256(keccak256(abi.encodePacked(msg.sender, _p2))) & 1) == 0;    
        uint256 emptyGame = (1 << 22); 
        uint256 setup = p1O ? emptyGame | (1 << 18) : emptyGame;
        Game memory g = Game((setup | (blockOffset << 23) | (block.number << 44) | (msg.value << 84 )  | (1 << 184) | (1 << 185)) , msg.sender, _p2);
        games[gameCounter] = g;
        gameId = gameCounter;
        emit newGame(gameId, msg.sender, _p2);
        unchecked {
            gameCounter = gameCounter + 1;
        }
        
    }

    event playerJoined(uint256 indexed _game);
    function acceptInvite(uint256 _game) public payable{
        Game memory currentGame = loadGame(_game);
        require(currentGame.P2 == msg.sender,"You can't join this game.");
        require(gameState(currentGame.gameSetup) == GameState.Open,"This game does not accept new players at this time.");
        require(getJackPotValue(currentGame.gameSetup) == msg.value, "You need to call the game initiator bet.");
        currentGame.gameSetup = currentGame.gameSetup | (1 << 21);
        games[_game] = currentGame;
        emit playerJoined(_game);
    }


    function settleAbuse(uint256 _game) public returns(GameState) {
        Game memory currentGame = loadGame(_game);
        require(gameState(currentGame.gameSetup) == GameState.InProgress, "This game is not in progress.");
        require((currentGame.P1 == msg.sender)||(currentGame.P2 == msg.sender), "You are not part of this game.");
        bool p1Turn = player1Turn(currentGame.gameSetup);
        if(getBlockNumber(currentGame.gameSetup) + getBlockOffset(currentGame.gameSetup) < block.number) {
            if(p1Turn) currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
            else currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
            GameState state = gameState(currentGame.gameSetup);
            if(state == GameState.P1Victory) emit gameFinished(_game, currentGame.P1);
            if(state == GameState.P2Victory) emit gameFinished(_game, currentGame.P2);
            games[_game] = currentGame;
            return state;
        }
        return GameState.InProgress;
    }

    function withdrawJackpot(uint256 _game) public returns(bool) {
        Game memory currentGame = loadGame(_game);
        GameState state = gameState(currentGame.gameSetup);
        uint256 jackPot = getJackPotValue(currentGame.gameSetup);
        if(state == GameState.P1Victory && msg.sender == currentGame.P1) {
            require(!p1Withdrawed(currentGame.gameSetup), "You have already withdrawn your funds.");
            jackPot = jackPot * 2;
            uint256 gameFee = jackPot / 10;
            fees = fees + gameFee;
            jackPot = jackPot - gameFee;
            currentGame.gameSetup = currentGame.gameSetup ^ (1 << 184);
            games[_game] = currentGame;
            (bool success, ) = payable(msg.sender).call{value: jackPot}("");
            require(success, "Failed to send Ether to the winner");
            return true;
        } else if (state == GameState.P2Victory && msg.sender == currentGame.P2){
            require(!p2Withdrawed(currentGame.gameSetup), "You have already withdrawn your funds.");
            jackPot = jackPot * 2;
            uint256 gameFee = jackPot / 10;
            fees = fees + gameFee;
            jackPot = jackPot - gameFee;
            currentGame.gameSetup = currentGame.gameSetup ^ (1 << 185);
            games[_game] = currentGame;
            (bool success, ) = payable(msg.sender).call{value: jackPot}("");
            require(success, "Failed to send Ether to the winner");
            return true;
        } else if(state == GameState.Draw) {
            if(msg.sender == currentGame.P1) {
                require(!p1Withdrawed(currentGame.gameSetup), "You have already withdrawn your funds.");
                uint256 gameFee = jackPot / 10;
                fees = fees + gameFee;
                jackPot = jackPot - gameFee;
                currentGame.gameSetup = currentGame.gameSetup ^ (1 << 184);
                games[_game] = currentGame;
                (bool success, ) = payable(msg.sender).call{value: jackPot}("");
                require(success, "Failed to send Ether to the winner");
                return true;
            }
            if(msg.sender == currentGame.P2) {
                require(!p2Withdrawed(currentGame.gameSetup), "You have already withdrawn your funds.");
                uint256 gameFee = jackPot / 10;
                fees = fees + gameFee;
                jackPot = jackPot - gameFee;
                currentGame.gameSetup = currentGame.gameSetup ^ (1 << 185);
                games[_game] = currentGame;
                (bool success, ) = payable(msg.sender).call{value: jackPot}("");
                require(success, "Failed to send Ether to the winner");
                return true;
            }
        }

        revert("You can't withdraw.");
    }

    function withdrawFees() external onlyOwner {
        uint256 feesToSend = fees;
        fees = 0;
        (bool success, ) = payable(owner()).call{value: feesToSend}("");
        require(success, "Failed to send Ether to the owner");
    }

    function initialize() initializer public {
        __Ownable_init(msg.sender);
        __Multicall_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}