pragma solidity ^0.4.23;

contract Reputation {

  address owner;
  mapping(address => bool) whitelist;
  mapping(address => int) ratings;

  constructor () public {
    owner = msg.sender;
  }

  function addToWhitelist(address _contractAddress) public {
    require(msg.sender == owner);
    whitelist[_contractAddress] = true;
  }

  function change(address _userAddress, int _delta) public {
    require(whitelist[msg.sender]);
    ratings[_userAddress] += _delta;
  }

  function getMy() public view returns (int) {
    return ratings[msg.sender];
  }

  function get(address _userAddress) public view returns (int) {
    return ratings[_userAddress];
  }
}
