pragma solidity ^0.5.0;

import "@ensdomains/ens/contracts/ENSRegistry.sol";
import "@ensdomains/ens/contracts/FIFSRegistrar.sol";
import "@ensdomains/ens/contracts/ReverseRegistrar.sol";
import "@ensdomains/resolver/contracts/PublicResolver.sol";

// Construct a set of test ENS contracts.
contract SLDRegistrar {
  bytes32 constant RESOLVER_LABEL = keccak256("resolver");
  bytes32 constant REVERSE_REGISTRAR_LABEL = keccak256("reverse");
  bytes32 constant ADDR_LABEL = keccak256("addr");
  
  ENSRegistry immutable ens;
  address immutable owner;
  string immutable tld;

  function namehash(bytes32 node, bytes32 label) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(node, label));
  }

  /**
    @dev
    @param _tld -  TLD matching exact input to XNHNS system  TLD to setup SLD registar ofor
    @param _owner - future owner of the registrar, does not have to be current owner of TLD
    @param _ens - ENS instance that TLD is registered and approved on
   */
  constructor(ENS _ens, address _owner, string memory _tld) public {
    owner = _owner;
    ens = _ens;
    tld = _tld;
  }

  /*
    @dev Ensure you call setApprovaleForAll on ENS registry from current TLD owner to this contract.
    Only then call this function.
  */
  function launchRegistrar() external {
    PublicResolver publicResolver = new PublicResolver(ens);
    bytes32 tldLabel = keccak256(tld);

    // Set up the resolver
    bytes32 tldNode = namehash(bytes32(0), keccak256(tld));
    bytes32 resolverNode = namehash(tldNode, RESOLVER_LABEL);

    ens.setSubnodeOwner(tldNode, RESOLVER_LABEL, address(this));
    ens.setResolver(resolverNode, address(publicResolver));
    publicResolver.setAddr(resolverNode, address(publicResolver));
    

    // Set up the reverse registrar
    ens.setSubnodeOwner(tldNode, REVERSE_REGISTRAR_LABEL, address(this));
    ens.setSubnodeOwner(namehash(tldNode, REVERSE_REGISTRAR_LABEL), ADDR_LABEL, address(reverseRegistrar));

    // Construct a new reverse registrar and point it at the public resolver
    reverseRegistrar = new ReverseRegistrar(ens, NameResolver(address(publicResolver))); 

    // Create a FIFS registrar for the TLD
    FIFSRegistrar fifsRegistrar = new FIFSRegistrar(ens, namehash(bytes32(0), TLD_LABEL));

    // Once TLD setup is complete transfer ownership to SLD registrar
    ens.setOwner(tldNode, address(fifsRegistrar));
  }
}
