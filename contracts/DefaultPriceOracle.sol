import "@ensdomains/ens-contracts/contracts/ethregistrar/PriceOracle.sol";

contract DefaultPriceOracle is PriceOracle {

  address public owner;
  // Rent in base price units by length. Element 0 is for 1-length names, and so on.
  uint[] public rentPrices;

  event NewPrices(uint[] indexed prices);
  event NewOwner(address owner);

  constructor(address _owner, uint[] memory prices) {
    owner = _owner;
    rentPrices = prices;

    emit NewPrices(prices);
    emit NewOwner(_owner);
  }

  function price(string calldata name, uint expires, uint duration) external view returns(uint) {
    uint len = name.strlen();
    require(len > 0);
    if(len > rentPrices.length) {
      len = rentPrices.length;
    }
    
    uint basePrice = rentPrices[len - 1].mul(duration);
    basePrice = basePrice.add(_premium(name, expires, duration));
  }

  function setPrices(uint[] memory prices) external {
    require(msg.sender == owner);
    rentPrices = prices;
  }

  function transferOwnership(address newOwner) external {
    require(msg.sender == owner);
    owner = newOwner;
  }



    /**
    * @dev Returns the length of a given string
    * source: https://github.com/ensdomains/ens-contracts/blob/master/contracts/ethregistrar/StringUtils.sol
    * @param s The string to measure the length of
    * @return The length of the input string
    */
  function strlen(string memory s) internal pure returns (uint) {
      uint len;
      uint i = 0;
      uint bytelength = bytes(s).length;
      for(len = 0; i < bytelength; len++) {
          bytes1 b = bytes(s)[i];
          if(b < 0x80) {
              i += 1;
          } else if (b < 0xE0) {
              i += 2;
          } else if (b < 0xF0) {
              i += 3;
          } else if (b < 0xF8) {
              i += 4;
          } else if (b < 0xFC) {
              i += 5;
          } else {
              i += 6;
          }
      }
      return len;
  }
}
