pragma solidity ^0.5.0;

import "@ensdomains/ens-contracts/contracts/registry/ENS.sol";

import "@ensdomains/ens-contracts/contracts/ethregistrar/BaseRegistrarImplementation.sol";
import "@ensdomains/ens-contracts/contracts/ethregistrar/ETHRegistrarController.sol";
import "@ensdomains/ens-contracts/contracts/registry/ReverseRegistrar.sol";
import "@ensdomains/ens-contracts/contracts/resolvers/PublicResolver.sol";
import "./DefaultPriceOracle"


// Construct a set of test ENS contracts.
contract SLDRegistrarFactory {
  // TODO precompute
  bytes32 constant RESOLVER_LABEL = keccak256("resolver");
  bytes32 constant REVERSE_REGISTRAR_LABEL = keccak256("reverse");
  bytes32 constant ADDR_LABEL = keccak256("addr");
  
  ENS immutable ens;
  PublicResolver immutable resolver;
  uint[] constant defaultPrices = [1 ether, 0.75 ether, 0.5 ether, 0.2 ether, 0.1 ether];

  event NewRegistrar(bytes32 indexed node, address indexed registrar, address registrarOwner);

  /**
    @dev
    @param _ens - ENS instance that TLD is registered and approved on
    @param _resolver - Generalized PublicResolver shared by all XNHNS TLDs
   */
  constructor(ENS _ens, PublicResolver _resolver) public {
    ens = _ens;
    resolver = _resolver;
  }

  function namehash(bytes32 node, bytes32 label) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(node, label));
  }

  /*
    @dev - Ensure you call setApprovaleForAll on ENS registry from current TLD owner to this contract.
    Only then call this function.

    @param registrarOWner - Address that will own SLD registrar and accrue revenue
    @param tld -  TLD matching exact input to XNHNS system  TLD to setup SLD registar ofor

  */
  function launchRegistrar(address registrarOwner, string memory tld) external returns (address registrar){
    require(ens.isApprovedForAll(msg.sender, address(this)), "SLDRegistrarFactory: Factory not TLD operator");
    
    bytes32 tldNode = namehash(bytes32(0), keccak256(tld));
    require(ens.owner(bytes32(0)).ownerOf(uint256(tldNode)), "SLDRegistrarFactory: Not NFLTD owner");

    // Set up the resolver
    bytes32 resolverNode = namehash(tldNode, RESOLVER_LABEL);
    ens.setSubnodeOwner(tldNode, RESOLVER_LABEL, address(this));
    ens.setResolver(resolverNode, address(publicResolver));
    publicResolver.setAddr(resolverNode, address(publicResolver));
    

    // TODO create singleton reverse resolver for all XNHNS TLDs at reverseResolver.xnhns/
    // Construct a new reverse registrar and point it at the public resolver
    reverseRegistrar = new ReverseRegistrar(ens, NameResolver(address(publicResolver))); 
    // Set up the reverse registrar domains
    ens.setSubnodeOwner(tldNode, REVERSE_REGISTRAR_LABEL, address(this));
    ens.setSubnodeOwner(namehash(tldNode, REVERSE_REGISTRAR_LABEL), ADDR_LABEL, address(reverseRegistrar));
    // give control of reverse registrar back to tld owner
    ens.setSubnodeOwner(tldNode, REVERSE_REGISTRAR_LABEL, msg.sender);

    // Deploy SLD registrar for the TLD
    BaseRegistrarImplementation sldRegistrar = new BaseRegistrarImplementation(ens, tldNode);
    DefaultPriceOracle priceOracle = new DefaultPriceOracle(defaultPrices);
    ETHRegistrarController controller = new ETHRegistrarController(sldRegistrar, PriceOracle(priceOracle), 30 seconds, 12 hours);

    sldRegistrar.addController(controller);

    // Once registrar is setup is transfer TLD ownership
    ens.setOwner(tldNode, address(sldRegistrar));
    // transfer registrar ownership from factory to TLD owner
    sldRegistrar.transferOwnership(registrarOwner);

    emit NewRegistrar(tldNode, sldRegistrar, registrarOwner);

    return address(sldRegistrar);
  }
}
