pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./NFTShardPoolP.sol";

contract NFTShardFactory2 is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public ID;
    address public NFTShardERC721;
    address public ChainlinkPriceFeedAddr;

    struct Pool {
        uint256 id;
        string poolNftURI;
        address poolAddress;
        address poolOwner;
    }

    Pool[] poolList;

    constructor(address _addr, address _priceFeed) public {
        NFTShardERC721 = _addr;
        ChainlinkPriceFeedAddr = _priceFeed;
        ID = 0;
    }

    function createPool(string memory name, string memory URI, uint256 totalPrice, uint256 totalShards, uint256 deadline) public nonReentrant returns (bool) {
        // require unique URI
       require(totalShards > 0 && totalPrice> 0 && deadline > 0, "value input is 0");

       NFTShardPoolP _newPoolAddress = new NFTShardPoolP(ID, name, URI, totalPrice, deadline, totalShards, msg.sender, NFTShardERC721, ChainlinkPriceFeedAddr);

       Pool memory _newPool = Pool({
           id: ID,
           poolNftURI: URI,
           poolAddress: address(_newPoolAddress),
           poolOwner: msg.sender
       });
       poolList.push(_newPool);

       ID = ID.add(1); 

       return true;
    }


    function listPools() public view returns(Pool[] memory) {
        return poolList;
    }

}