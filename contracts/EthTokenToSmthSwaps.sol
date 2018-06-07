pragma solidity ^0.4.23;

import './Reputation.sol';
import './SafeMath.sol';
import './Interfaces.sol';

contract EthTokenToSmthSwaps {

  using SafeMath for uint;
  
  address public owner;
  address public ratingContractAddress;
  uint256 SafeTime = 4 seconds; // atomic swap timeOut

  struct Swap {
    address token;
    bytes32 secret;
    bytes20 secretHash;
    uint256 createdAt;
    uint256 balance;
  }

  // ETH Owner => BTC Owner => Swap
  mapping(address => mapping(address => Swap)) public swaps;
  mapping(address => mapping(address => uint)) public participantSigns;

  constructor () public {
    owner = msg.sender;
  }

  function setReputationAddress(address _ratingContractAddress) public {
    require(owner == msg.sender);
    ratingContractAddress = _ratingContractAddress;
  }

  // ETH Owner signs swap
  // initializing time for correct work of close() method
  function sign(address _participantAddress) public {
    participantSigns[msg.sender][_participantAddress] = now;
  }

  // BTC Owner checks if ETH Owner signed swap
  function checkSign(address _ownerAddress) public view returns (uint) {
    return participantSigns[_ownerAddress][msg.sender];
  }

  // ETH Owner creates Swap with secretHash
  // ETH Owner make token deposit
  function createSwap(bytes20 _secretHash, address _participantAddress, uint256 _value, address _token) public {
    require(_value > 0);
    require(participantSigns[msg.sender][_participantAddress].add(SafeTime) > now);
    require(swaps[msg.sender][_participantAddress].balance == uint256(0));
    require(ERC20(_token).transferFrom(msg.sender, this, _value));

    swaps[msg.sender][_participantAddress] = Swap(
      _token,
      bytes32(0),
      _secretHash,
      now,
      _value
    );
  }

  function getInfo(address _ownerAddress, address _participantAddress) public view returns (address, bytes32,  bytes20,  uint256,  uint256) {
    Swap memory swap = swaps[_ownerAddress][_participantAddress];

    return (swap.token, swap.secret, swap.secretHash, swap.createdAt, swap.balance);
  }

  // BTC Owner withdraw money and adds secret key to swap
  // BTC Owner receive +1 reputation
  function withdraw(bytes32 _secret, address _ownerAddress) public {
    Swap memory swap = swaps[_ownerAddress][msg.sender];
    
    require(swap.secretHash == ripemd160(_secret));
    require(swap.balance > uint256(0));
    require(swap.createdAt.add(SafeTime) > now);

    Reputation(ratingContractAddress).change(msg.sender, 1);
    ERC20(swap.token).transfer(msg.sender, swap.balance);

    swaps[_ownerAddress][msg.sender].balance = 0;
    swaps[_ownerAddress][msg.sender].secret = _secret;
  }

  // ETH Owner receive secret
  function getSecret(address _participantAddress) public view returns (bytes32) {
    return swaps[msg.sender][_participantAddress].secret;
  }
  
  // ETH Owner closes swap
  // ETH Owner receive +1 reputation
  function close(address _participantAddress) public {
    Reputation(ratingContractAddress).change(msg.sender, 1);
    clean(msg.sender, _participantAddress);
  }

  // ETH Owner refund money
  // BTC Owner gets -1 reputation
  function refund(address _participantAddress) public {
    Swap memory swap = swaps[msg.sender][_participantAddress];
    
    require(swap.createdAt.add(SafeTime) < now);
    
    ERC20(swap.token).transfer(msg.sender, swap.balance);
    // TODO it looks like ETH Owner can create as many swaps as possible and refund them to decrease someone reputation
    Reputation(ratingContractAddress).change(_participantAddress, -1);
    clean(msg.sender, _participantAddress);
  }

  // BTC Owner closes Swap
  // If ETH Owner don't create swap after init in in safeTime
  // ETH Owner -1 reputation
  function abort(address _ownerAddress) public {
    require(swaps[_ownerAddress][msg.sender].balance == uint256(0));
    require(participantSigns[_ownerAddress][msg.sender] != uint(0));
    require(participantSigns[_ownerAddress][msg.sender].add(SafeTime) < now);
    
    Reputation(ratingContractAddress).change(_ownerAddress, -1);
    clean(_ownerAddress, msg.sender);
  }

  function unsafeGetSecret(address _ownerAddress, address _participantAddress) public view returns (bytes32) {
    return swaps[_ownerAddress][_participantAddress].secret;
  }

  function clean(address _ownerAddress, address _participantAddress) internal {
    delete swaps[_ownerAddress][_participantAddress];
    delete participantSigns[_ownerAddress][_participantAddress];
  }
}
