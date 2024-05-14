//// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

import {AxelarExecutable} from "axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

contract TicTacToeV3git is AxelarExecutable, Ownable {

    address public sepoliaAddress;
    address public arbiSepoliaAddress;
    IAxelarGasService public immutable gasService;

    constructor(address gateway_, address gasReceiver_) AxelarExecutable(gateway_) Ownable(msg.sender) {
        gasService = IAxelarGasService(gasReceiver_);
    }

    function setSepoliaAddress(address sp_address) public onlyOwner(){
        sepoliaAddress = sp_address;
    }

    function setarbiSepoliaAddress(address ar_sp_address) public onlyOwner(){
        arbiSepoliaAddress = ar_sp_address;
    }

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
        bool multiChain;
    }

    mapping (uint256 => Game) games;
    uint256 public gameCounter = 0;
    uint256[100] ______gap;

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
    function Move(uint256 _game, uint8 _x, uint8 _y) payable public returns (GameState) {
        uint256 move = _y * 3 + _x;  
        require(_x < 3, "Invalid Move.");
        require(_y < 3, "Invalid Move.");
        Game memory currentGame = loadGame(_game);
        require(gameState(currentGame.gameSetup) == GameState.InProgress, "This game is not in progress.");
        bool p1Turn = player1Turn(currentGame.gameSetup);
        require((p1Turn && currentGame.P1 == msg.sender) || (!p1Turn && currentGame.P2 == msg.sender), "You are either not part of the game or it is not your turn.");
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
            if(currentGame.multiChain){
                sendMessage(abi.encode("move", _x, _y, _game, address(0), address(0), state));
            }
            return state;
        }
        uint256 gameSetup = currentGame.gameSetup;
        unchecked {
            for(uint256  i= 0; i<9; ++i){
                //get only the last two digit 3 => 11
                if((gameSetup & 3) == 0) {
                    games[_game] = currentGame;
                    if(currentGame.multiChain){
                        sendMessage(abi.encode("move", _x, _y, _game, address(0), address(0), state));
                    }
                    return state;
                }
                gameSetup = gameSetup >> 2;
            }
        }

        currentGame.gameSetup = setDraw(currentGame.gameSetup);
        emit gameFinished(_game, address(0));
        games[_game] = currentGame;
        if(currentGame.multiChain){
            sendMessage(abi.encode("move", _x, _y, _game, address(0), address(0), GameState.Draw));
        }
        return GameState.Draw;
    }

    function move(uint256 _game, uint8 _x, uint8 _y, GameState state) payable public {
        uint256 move = _y * 3 + _x;  
        Game memory currentGame = loadGame(_game);
        if(state == GameState.P1Victory){
            currentGame.gameSetup = setP1Winner(currentGame.gameSetup);
        }
        else if(state == GameState.P2Victory){
            currentGame.gameSetup = setP2Winner(currentGame.gameSetup);
        }
        else if(state == GameState.Draw){
            currentGame.gameSetup = setDraw(currentGame.gameSetup);
        } else {
            bool p1Turn = player1Turn(currentGame.gameSetup);
            uint256 playerMoveIndicator = (p1Turn ? 0 : 1);
            move = move << 1;
            currentGame.gameSetup = currentGame.gameSetup ^ (1 << (move + playerMoveIndicator));
            currentGame.gameSetup = currentGame.gameSetup ^ (1 << 18);
            games[_game] = currentGame;
        }
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

    event newGame(uint256 indexed _game, address _p1, address _p2);
    function openNewGame(address _p2, bool multiChain)payable public returns(uint256 gameId){

        bool p1O = (uint256(keccak256(abi.encodePacked(msg.sender, _p2))) & 1) == 0;    
        uint256 emptyGame = (1 << 22); 
        Game memory g = Game(p1O ? emptyGame | (1 << 18) : emptyGame , msg.sender, _p2, multiChain);
        games[gameCounter] = g;
        gameId = gameCounter;
        emit newGame(gameId, msg.sender, _p2);
        unchecked {
            gameCounter = gameCounter + 1;
        }

        if(multiChain){
            require(msg.value>0);
            sendMessage(abi.encode("open", 0, 0, gameId, msg.sender, _p2, GameState.Open));
        }
    }

    function openNewGame(address _p1, address _p2, uint256 gameId) private{
        //require(msg.sender != _p2, "You can't invite yourself to play");
        require(gameId > gameCounter);
        bool p1O = (uint256(keccak256(abi.encodePacked(_p1, _p2))) & 1) == 0;    
        uint256 emptyGame = (1 << 22); 
        Game memory g = Game(p1O ? emptyGame | (1 << 18) : emptyGame , _p1, _p2, true);
        games[gameCounter] = g;
        gameCounter = gameId + 1;
        emit newGame(gameId, _p1, _p2);    
    }
    
    event playerJoined(uint256 indexed _game);
    function acceptInvite(uint256 _game)payable public{
        Game memory currentGame = loadGame(_game);
        require(currentGame.P2 == msg.sender,"You can't join this game.");
        require(gameState(currentGame.gameSetup) == GameState.Open,"This game does not accept new players at this time.");
        if(currentGame.multiChain){
            sendMessage(abi.encode("accept", 0, 0, _game, address(0), msg.sender, GameState.InProgress));
        }
        currentGame.gameSetup = currentGame.gameSetup | (1 << 21);
        games[_game] = currentGame;
        emit playerJoined(_game);
    }

    function acceptInvite(uint256 _game, address _p2) private{
        Game memory currentGame = loadGame(_game);
        require(currentGame.P2 == _p2,"You can't join this game.");
        require(gameState(currentGame.gameSetup) == GameState.Open,"This game does not accept new players at this time.");
        currentGame.gameSetup = currentGame.gameSetup | (1 << 21);
        games[_game] = currentGame;
        emit playerJoined(_game);
    }


    function sendMessage(
        bytes memory message_
    ) private {
        string memory destinationChain = "";
        string memory destinationAddress = "";
        if(address(this) == sepoliaAddress){
            destinationChain = "arbitrum-sepolia";
            string(abi.encodePacked(arbiSepoliaAddress)); 
        }
        else if(address(this) == arbiSepoliaAddress){

            destinationChain = "ethereum-sepolia";
            destinationAddress = string(abi.encodePacked(sepoliaAddress)); 
        }
        bytes memory payload = message_;
        gasService.payNativeGasForContractCall{value: msg.value} (
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );

        gateway.callContract(destinationChain,destinationAddress,payload);
    }

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload_
    ) internal override {
        (string memory method, uint8 x, uint8 y, uint256 gameId, address p1, address p2, GameState state) = abi.decode(payload_, (string, uint8, uint8, uint256, address, address, GameState ));
        if(address(this) == sepoliaAddress){ 
            require(keccak256(abi.encodePacked(sourceAddress)) == keccak256(abi.encodePacked(arbiSepoliaAddress)));
        }
        else if(address(this) == arbiSepoliaAddress){
            require(keccak256(abi.encodePacked(sourceAddress)) == keccak256(abi.encodePacked(sepoliaAddress)), "");
        }
        if(keccak256(abi.encodePacked(method)) == keccak256(abi.encodePacked("open"))) openNewGame(p1,p2, gameId);
        if(keccak256(abi.encodePacked(method)) == keccak256(abi.encodePacked("accept"))) acceptInvite(gameId, p2 );
        if(keccak256(abi.encodePacked(method)) == keccak256(abi.encodePacked("move"))) move(gameId, x, y, state);
    }
}