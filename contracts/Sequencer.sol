pragma solidity ^0.5.0;

contract Ownable {
  address public owner;

  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }
}


contract Authorizable is Ownable {

    mapping(address => bool) public authorized;

    modifier onlyAuthorized() {
      require(authorized[msg.sender] || owner == msg.sender);
      _;
    }

    function addAuthorized(address _toAdd) onlyOwner public {
      require(_toAdd != address(0));
      authorized[_toAdd] = true;
    }

    function removeAuthorized(address _toRemove) onlyOwner public {
      require(_toRemove != address(0));
      require(_toRemove != msg.sender);
      authorized[_toRemove] = false;
    }

}


contract Sequencer is Authorizable {

    event SequenceGenerated(
      bytes16 indexed _idbook,
      bytes32 indexed _digest,
      uint sequence
    );

    struct Document {
      uint sequence;
      bytes32 digest;
      uint timestamp;
      address signer;
    }

    struct Book {
      address[] bookSigners;
      Document[] documents;
      uint firstIndex;
    }

    mapping (bytes16 => Book) private book;

    function addBookSigner(bytes16 _idbook,address _signer) onlyAuthorized public {
      require(_signer != address(0));
      book[_idbook].bookSigners.push(_signer);
    }

    function removeBookSigner(bytes16 _idbook,address _signer) onlyAuthorized public {
      require(_signer != address(0));
      for (uint i = 0; i < book[_idbook].bookSigners.length; i++) {
        if (book[_idbook].bookSigners[i] == _signer) {
          delete book[_idbook].bookSigners[i];
        }
      }
    }

    function getBookSigner(bytes16 _idbook) view public returns (address[] memory) {
      return (book[_idbook].bookSigners);
    }

    function setBookFirstIndex(bytes16 _idbook, uint _index) onlyAuthorized public {
      require(book[_idbook].documents.length == 0, "Book already in use.");
      book[_idbook].firstIndex=_index;
    }

    function getBookFirstIndex(bytes16 _idbook) view public returns (uint) {
      return (book[_idbook].firstIndex);
    }

    function addDocument(bytes16 _idbook,bytes32 _digest, uint8 _v,bytes32 _r,bytes32 _s) public returns (uint) {
      bool isDuplicated=false;

      for (uint i = 0; i < book[_idbook].documents.length; i++) {
        if (book[_idbook].documents[i].digest==_digest) {
          isDuplicated=true;
        }
      }

      require (!isDuplicated, "Digest already exist in that book.");

      bytes32 messageHash = keccak256(abi.encodePacked(_idbook, _digest));

      if (_v < 27) {
         _v += 27;
      }
      
      address recovered=ecrecover(messageHash, _v, _r, _s);

      bool isBookSigner=false;

      for (uint j = 0; j < book[_idbook].bookSigners.length; j++) {
        if (book[_idbook].bookSigners[j]==recovered) {
          isBookSigner=true;
        }
      }

      require (isBookSigner,"No authorized signatures found.");

      Document memory document;
      document.sequence = book[_idbook].documents.length + book[_idbook].firstIndex;
      document.digest = _digest;
      document.timestamp = block.timestamp;
      document.signer = recovered;

      book[_idbook].documents.push(document);

      emit SequenceGenerated(_idbook, _digest, document.sequence);

      return (document.sequence);
    }

    function getDocumentsCount(bytes16 _idbook)  view public returns (uint) {
        return (book[_idbook].documents.length);
    }

    function getDocument(bytes16 _idbook, uint _seq) view public returns (uint sequence, bytes32 digest, uint timestamp, address signer) {
      uint index = _seq - book[_idbook].firstIndex;
      return (
        book[_idbook].documents[index].sequence,
        book[_idbook].documents[index].digest,
        book[_idbook].documents[index].timestamp,
        book[_idbook].documents[index].signer
      );
    }

    function getDocumentSequence(bytes16 _idbook, bytes32 _digest) view public returns (uint) {
      for (uint i = 0; i < book[_idbook].documents.length; i++) {
        if (book[_idbook].documents[i].digest==_digest) {
          return (i + book[_idbook].firstIndex);
        }
      }
    }

}